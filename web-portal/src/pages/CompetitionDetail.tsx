import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { BarChart, Bar, XAxis, YAxis, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { ArrowLeft, Activity, Users, Image as ImageIcon, Upload, Play, Download, Settings, ChevronRight, AlertTriangle, Lock } from 'lucide-react';

export default function CompetitionDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('dashboard');
  const [dashboard, setDashboard] = useState<any>(null);
  const [leaderboard, setLeaderboard] = useState<any>(null);
  const [models, setModels] = useState<any[]>([]);
  const [teams, setTeams] = useState<any[]>([]);
  const [role, setRole] = useState<string>('none');
  const [myTeamId, setMyTeamId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  
  // Evaluation modal state
  const [evalModalModelId, setEvalModalModelId] = useState<number | null>(null);
  const [evalProtocol, setEvalProtocol] = useState('standard');
  const [evaluating, setEvaluating] = useState(false);
  const [evalResult, setEvalResult] = useState<string>('');
  const [uploading, setUploading] = useState(false);
  
  // History modal state
  const [historyModalModelId, setHistoryModalModelId] = useState<number | null>(null);
  const [modelHistory, setModelHistory] = useState<any[]>([]);
  const [loadingHistory, setLoadingHistory] = useState(false);
  
  // Export states
  const [globalExportFormat, setGlobalExportFormat] = useState('csv');
  const [teamExportFormats, setTeamExportFormats] = useState<{[key: number]: string}>({});
  
  // Cleaner state
  const [cleanerStatus, setCleanerStatus] = useState<string>('Idle');
  const [cleanerStats, setCleanerStats] = useState<any>(null);

  // Dataset gallery state
  const [datasetImages, setDatasetImages] = useState<any[]>([]);
  const [datasetLoading, setDatasetLoading] = useState(false);
  
  // Invite modal state
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [inviteTokenValue, setInviteTokenValue] = useState('');
  
  // Team management state
  const [showCreateTeam, setShowCreateTeam] = useState(false);
  const [newTeamName, setNewTeamName] = useState('');
  const [showAddMember, setShowAddMember] = useState<number | null>(null); // team_id or null
  const [unassigned, setUnassigned] = useState<any[]>([]);
  const [teamActionLoading, setTeamActionLoading] = useState(false);

  // Phase confirmation
  const [showPhaseConfirm, setShowPhaseConfirm] = useState(false);
  // Settings tab
  const [showSettings, setShowSettings] = useState(false);
  const [configLabels, setConfigLabels] = useState('');
  const [configThreshold, setConfigThreshold] = useState('1');
  const [savingConfig, setSavingConfig] = useState(false);

  useEffect(() => {
    fetchData();

    // SSE Real-time Updates
    const token = localStorage.getItem('token');
    if (!token || !id) return;
    
    const es = new EventSource(`http://localhost:8000/api/v1/competitions/${id}/dashboard/stream?token=${token}`);
    
    es.addEventListener('update', (event) => {
      try {
        const data = JSON.parse(event.data);
        setDashboard(data);
        
        // Also fetch leaderboard when an update arrives, to keep it in sync live
        fetch(`http://localhost:8000/api/v1/competitions/${id}/leaderboard`, {
          headers: { 'Authorization': `Bearer ${token}` }
        }).then(res => res.ok && res.json()).then(lead => {
          if (lead) setLeaderboard(lead);
        }).catch(console.error);

      } catch (e) {
        console.error("SSE parse error", e);
      }
    });

    return () => {
      es.close();
    };
  }, [id]);

  useEffect(() => {
    if (activeTab === 'dataset') {
      fetchDatasetImages();
    }
  }, [activeTab, id]);

  const fetchDatasetImages = async () => {
    setDatasetLoading(true);
    const token = localStorage.getItem('token');
    try {
      const res = await fetch(`http://localhost:8000/api/v1/competitions/${id}/images`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setDatasetImages(data.images || []);
      }
    } catch (e) {
      console.error("Failed to fetch dataset", e);
    }
    setDatasetLoading(false);
  };

  const fetchData = async () => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/login');

    try {
      const [dashRes, leadRes, modelsRes, roleRes, teamsRes] = await Promise.all([
        fetch(`http://localhost:8000/api/v1/competitions/${id}/dashboard`, {
          headers: { 'Authorization': `Bearer ${token}` }
        }),
        fetch(`http://localhost:8000/api/v1/competitions/${id}/leaderboard`, {
          headers: { 'Authorization': `Bearer ${token}` }
        }),
        fetch(`http://localhost:8000/api/v1/competitions/${id}/models`, {
          headers: { 'Authorization': `Bearer ${token}` }
        }).catch(() => ({ ok: false, json: async () => ({ items: [] }) })),
        fetch(`http://localhost:8000/api/v1/competitions/${id}/my-role`, {
          headers: { 'Authorization': `Bearer ${token}` }
        }),
        fetch(`http://localhost:8000/api/v1/competitions/${id}/teams`, {
          headers: { 'Authorization': `Bearer ${token}` }
        }).catch(() => ({ ok: false, json: async () => ({ items: [] }) }))
      ]);

      if (dashRes.ok) setDashboard(await dashRes.json());
      if (leadRes.ok) setLeaderboard(await leadRes.json());
      if (modelsRes && 'ok' in modelsRes && modelsRes.ok) {
        const mods = await modelsRes.json();
        setModels(mods.items || []);
      }
      if (roleRes.ok) {
        const r = await roleRes.json();
        setRole(r.role);
        setMyTeamId(r.team_id || null);
      }
      if (teamsRes && 'ok' in teamsRes && teamsRes.ok) {
        const t = await teamsRes.json();
        // For each team, fetch members
        const teamsWithMembers = await Promise.all((t.items || []).map(async (team: any) => {
          const mRes = await fetch(`http://localhost:8000/api/v1/teams/${team.id}/members`, {
            headers: { 'Authorization': `Bearer ${token}` }
          });
          if (mRes.ok) {
            const mData = await mRes.json();
            return { ...team, members: mData.members };
          }
          return { ...team, members: [] };
        }));
        setTeams(teamsWithMembers);
      }
    } catch (err) {
      setError('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  const createTeam = async () => {
    if (!newTeamName.trim()) return;
    setTeamActionLoading(true);
    const token = localStorage.getItem('token');
    try {
      const res = await fetch(`http://localhost:8000/api/v1/competitions/${id}/teams`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: newTeamName })
      });
      if (!res.ok) { const d = await res.json().catch(() => ({})); throw new Error(d.detail || 'Failed'); }
      setShowCreateTeam(false);
      setNewTeamName('');
      fetchData();
    } catch (e: any) {
      alert(e.message);
    } finally { setTeamActionLoading(false); }
  };

  const fetchUnassigned = async (teamId: number) => {
    const token = localStorage.getItem('token');
    const res = await fetch(`http://localhost:8000/api/v1/competitions/${id}/participants/unassigned`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    if (res.ok) {
      const data = await res.json();
      setUnassigned(data.participants || []);
      setShowAddMember(teamId);
    }
  };

  const addMemberToTeam = async (teamId: number, userId: number) => {
    setTeamActionLoading(true);
    const token = localStorage.getItem('token');
    try {
      const res = await fetch(`http://localhost:8000/api/v1/teams/${teamId}/members`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: userId })
      });
      if (!res.ok) { const d = await res.json().catch(() => ({})); throw new Error(d.detail || 'Failed'); }
      setShowAddMember(null);
      fetchData();
    } catch (e: any) {
      alert(e.message);
    } finally { setTeamActionLoading(false); }
  };

  const removeMemberFromTeam = async (teamId: number, userId: number) => {
    if (!confirm('Remove this member from the team?')) return;
    const token = localStorage.getItem('token');
    await fetch(`http://localhost:8000/api/v1/teams/${teamId}/members/${userId}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${token}` }
    });
    fetchData();
  };

  const deleteTeam = async (teamId: number) => {
    if (!confirm('Delete this team? This cannot be undone.')) return;
    const token = localStorage.getItem('token');
    await fetch(`http://localhost:8000/api/v1/teams/${teamId}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${token}` }
    });
    fetchData();
  };

  const runCleaner = async () => {
    setCleanerStatus('Running Cleaner...');
    const token = localStorage.getItem('token');
    try {
      await fetch(`http://localhost:8000/api/v1/competitions/${id}/cleaner/run`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      setCleanerStatus('Cleaning complete. Checking optimization...');
      
      const statRes = await fetch(`http://localhost:8000/api/v1/competitions/${id}/cleaner/optimize-storage`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (statRes.ok) {
        setCleanerStats(await statRes.json());
        setCleanerStatus('Completed');
      }
    } catch (e) {
      setCleanerStatus('Error running cleaner');
    }
  };

  const PHASE_ORDER = ['creation', 'active', 'evaluation', 'completed'];
  const PHASE_WARNINGS: Record<string, string> = {
    'creation': 'Moving to Active phase will allow teams to start uploading images via the mobile app.',
    'active': 'Moving to Evaluation phase will lock image uploads and enable model submissions.',
    'evaluation': 'Moving to Completed will finalize the competition. No more submissions allowed.',
  };

  const advancePhase = async () => {
    const token = localStorage.getItem('token');
    await fetch(`http://localhost:8000/api/v1/competitions/${id}/phase/advance`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${token}` }
    });
    setShowPhaseConfirm(false);
    fetchData();
  };

  const saveConfig = async () => {
    setSavingConfig(true);
    const token = localStorage.getItem('token');
    try {
      const labelsArr = configLabels.split(',').map(l => l.trim()).filter(Boolean);
      await fetch(`http://localhost:8000/api/v1/competitions/${id}/config`, {
        method: 'PUT',
        headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ labels: labelsArr, max_validations: parseInt(configThreshold) || 1 })
      });
      alert('Configuration saved!');
      fetchData();
    } catch (e) {
      alert('Failed to save config');
    } finally {
      setSavingConfig(false);
    }
  };

  const uploadModel = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    
    let teamId: number | null = null;
    if (role === 'participant') {
      if (myTeamId) {
        teamId = myTeamId;
      } else {
        alert('You are not assigned to a team yet.');
        e.target.value = '';
        return;
      }
    } else {
      // For hosts/staff if they ever upload
      if (teams.length === 1) {
        teamId = teams[0].id;
      } else if (teams.length > 1) {
        const teamNames = teams.map((t: any, i: number) => `${i + 1}. ${t.name} (ID: ${t.id})`).join('\n');
        const choice = prompt(`Select a team to submit for:\n${teamNames}\n\nEnter the team ID:`);
        if (!choice) { e.target.value = ''; return; }
        teamId = parseInt(choice);
        if (!teams.find((t: any) => t.id === teamId)) {
          alert('Invalid team ID');
          e.target.value = '';
          return;
        }
      } else {
        alert('No teams available to submit for');
        e.target.value = '';
        return;
      }
    }

    setUploading(true);
    const token = localStorage.getItem('token');
    const formData = new FormData();
    formData.append('file', file);

    try {
      const res = await fetch(`http://localhost:8000/api/v1/competitions/${id}/teams/${teamId}/models`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData
      });
      
      if (!res.ok) {
        const err = await res.json();
        alert('Upload failed: ' + (err.detail || 'Unknown error'));
      } else {
        alert('Model submitted successfully!');
        fetchData();
      }
    } catch (err) {
      alert('Upload error');
    } finally {
      setUploading(false);
      e.target.value = '';
    }
  };

  const evaluateModel = async (modelId: number, protocol: string) => {
    const token = localStorage.getItem('token');
    setEvaluating(true);
    setEvalResult('');
    try {
      const res = await fetch(`http://localhost:8000/api/v1/models/${modelId}/evaluate`, {
        method: 'POST',
        headers: { 
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ protocol, folds: 5 })
      });
      const data = await res.json();
      if (res.ok) {
        setEvalResult(`✅ ${data.message}`);
        fetchData();
      } else {
        setEvalResult(`❌ ${data.detail || 'Evaluation failed'}`);
      }
    } catch (err) {
      setEvalResult('❌ Evaluation error — is Docker running?');
    } finally {
      setEvaluating(false);
    }
  };

  const viewHistory = async (modelId: number) => {
    setHistoryModalModelId(modelId);
    setLoadingHistory(true);
    const token = localStorage.getItem('token');
    try {
      const res = await fetch(`http://localhost:8000/api/v1/models/${modelId}/evaluations`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setModelHistory(data.items || []);
      } else {
        alert('Failed to load history');
      }
    } catch (e) {
      alert('Error fetching history');
    } finally {
      setLoadingHistory(false);
    }
  };

  const exportTeamDataset = (teamId: number) => {
    const token = localStorage.getItem('token');
    const format = teamExportFormats[teamId] || 'csv';
    window.open(`http://localhost:8000/api/v1/teams/${teamId}/dataset/export?format=${format}&token=${token}`, '_blank');
  };

  const handleBulkImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const token = localStorage.getItem('token');
    const formData = new FormData();
    formData.append('file', file);
    try {
      const res = await fetch(`http://localhost:8000/api/v1/competitions/${id}/teams/bulk-import`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData
      });
      if (res.ok) {
        const data = await res.json();
        alert(`Success: ${data.message}`);
        window.location.reload();
      } else {
        const err = await res.json();
        alert(`Error: ${err.detail}`);
      }
    } catch (err) {
      alert('Failed to upload CSV');
    }
    e.target.value = '';
  };

  const handleLockDataset = async () => {
    if (!window.confirm("Are you sure you want to lock the dataset? This will prevent any further label modifications.")) return;
    const token = localStorage.getItem('token');
    try {
      const res = await fetch(`http://localhost:8000/api/v1/competitions/${id}/dataset/lock`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        alert("Dataset locked successfully.");
        window.location.reload();
      } else {
        const data = await res.json();
        alert(`Error: ${data.detail}`);
      }
    } catch (err) {
      alert("Failed to lock dataset");
    }
  };

  if (loading) return <div style={{ padding: '40px', color: 'white' }}>Loading...</div>;
  if (error) return <div className="error-msg">{error}</div>;
  if (!dashboard) return <div style={{ padding: '40px', color: 'white' }}>No data found.</div>;

  const imageStatsData = [
    { name: 'Verified', value: dashboard.image_stats.verified },
    { name: 'On Hold', value: dashboard.image_stats.on_hold },
  ];
  const COLORS = ['#00C49F', '#FFBB28'];

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
      <header className="header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <button 
          onClick={() => navigate('/dashboard')}
          style={{ background: 'none', border: 'none', color: 'white', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px' }}
        >
          <ArrowLeft size={20} /> Back
        </button>
        <div style={{ display: 'flex', gap: '6px' }}>
          {['dashboard', 'dataset', 'teams', ...(role === 'host' ? ['cleaner'] : []), 'models', ...(role === 'host' ? ['settings'] : [])].map(tab => (
            <button
              key={tab}
              className={`tab-btn ${activeTab === tab ? 'active' : ''}`}
              onClick={() => setActiveTab(tab)}
            >
              {tab === 'dashboard' ? 'Dashboard' : tab === 'dataset' ? 'Dataset' : tab === 'teams' ? 'Teams' : tab === 'cleaner' ? 'Cleaner' : tab === 'models' ? 'Models & Eval' : 'Settings'}
            </button>
          ))}
        </div>
        <div style={{ width: 80 }}></div>
      </header>

      <div className="dashboard-container">
        {activeTab === 'dashboard' ? (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '20px', marginBottom: '40px' }}>
              <div className="glass-panel" style={{ display: 'flex', alignItems: 'center', gap: '16px', justifyContent: 'space-between' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                  <Activity size={32} color="var(--primary)" />
                  <div>
                    <div style={{ color: 'var(--text-muted)' }}>Current Phase</div>
                    <h2 style={{ margin: 0, textTransform: 'capitalize' }}>{dashboard.phase_info?.current_phase || 'Setup'}</h2>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: '8px' }}>
                  {role === 'host' && !dashboard.phase_info?.dataset_locked && (
                    <button className="btn-secondary" style={{ padding: '6px 14px', fontSize: '12px', width: 'auto', display: 'inline-flex', alignItems: 'center', gap: '4px', background: 'rgba(239, 68, 68, 0.2)', color: '#ef4444', border: '1px solid rgba(239, 68, 68, 0.5)' }} onClick={handleLockDataset}>
                      <Lock size={14} /> Lock Dataset
                    </button>
                  )}
                  {role === 'host' && dashboard.phase_info?.current_phase !== 'completed' && (
                    <button className="btn-outline" style={{ padding: '6px 14px', fontSize: '12px', width: 'auto', display: 'inline-flex', alignItems: 'center', gap: '4px' }} onClick={() => setShowPhaseConfirm(true)}>
                      <ChevronRight size={14} /> Advance
                    </button>
                  )}
                </div>
              </div>
              <div className="glass-panel" style={{ display: 'flex', alignItems: 'center', gap: '16px', justifyContent: 'space-between' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                  <ImageIcon size={32} color="var(--primary)" />
                  <div>
                    <div style={{ color: 'var(--text-muted)' }}>Total Images</div>
                    <h2 style={{ margin: 0 }}>{dashboard.image_stats.total}</h2>
                  </div>
                </div>
                {dashboard.image_stats.total > 0 && (
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                    <select 
                      className="input-field" 
                      style={{ padding: '6px 12px', fontSize: '12px', width: 'auto', background: 'rgba(255,255,255,0.05)', color: 'white' }}
                      value={globalExportFormat}
                      onChange={(e) => setGlobalExportFormat(e.target.value)}
                    >
                      <option value="csv">CSV (Default)</option>
                      <option value="yolo">YOLO format</option>
                      <option value="coco">COCO format</option>
                    </select>
                    <button
                      className="btn-secondary"
                      style={{ padding: '6px 12px', fontSize: '12px', width: 'auto', display: 'flex', alignItems: 'center', gap: '6px' }}
                      onClick={() => {
                        const token = localStorage.getItem('token');
                        window.open(`http://localhost:8000/api/v1/competitions/${id}/dataset/export?format=${globalExportFormat}&token=${token}`, '_blank');
                      }}
                    >
                      <Download size={14} /> Export
                    </button>
                  </div>
                )}
              </div>
              <div className="glass-panel" style={{ display: 'flex', alignItems: 'center', gap: '16px', justifyContent: 'space-between' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                  <Users size={32} color="var(--primary)" />
                  <div>
                    <div style={{ color: 'var(--text-muted)' }}>Registered Teams</div>
                    <h2 style={{ margin: 0 }}>{dashboard.team_info?.total || dashboard.team_info?.total_teams || 0}</h2>
                  </div>
                </div>
                {role === 'host' && (
                  <button 
                    className="btn-secondary" 
                    style={{ padding: '6px 12px', fontSize: '12px', width: 'auto' }}
                    onClick={async () => {
                      const token = localStorage.getItem('token');
                      try {
                        const res = await fetch(`http://localhost:8000/api/v1/invitations/competitions/${id}/generate`, {
                          method: 'POST',
                          headers: { 'Authorization': `Bearer ${token}` }
                        });
                        if (res.ok) {
                          const data = await res.json();
                          const url = new URL(data.invitation_link);
                          const tokenParam = url.searchParams.get('token') || '';
                          setInviteTokenValue(tokenParam);
                          setShowInviteModal(true);
                        }
                      } catch (e) {
                        setError('Failed to generate invite token');
                      }
                    }}
                  >
                    Generate Invite
                  </button>
                )}
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '40px' }}>
              <div className="glass-panel">
                <h3 style={{ marginBottom: '20px' }}>Validation Status</h3>
                <div style={{ height: 300 }}>
                  {dashboard.image_stats.total > 0 ? (
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie data={imageStatsData} cx="50%" cy="50%" innerRadius={60} outerRadius={100} fill="#8884d8" paddingAngle={5} dataKey="value">
                          {imageStatsData.map((entry, index) => (
                            <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                          ))}
                        </Pie>
                        <Tooltip />
                        <Legend />
                      </PieChart>
                    </ResponsiveContainer>
                  ) : (
                    <div style={{ display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)' }}>
                      No images submitted yet.
                    </div>
                  )}
                </div>
              </div>

              <div className="glass-panel">
                <h3 style={{ marginBottom: '20px' }}>Leaderboard Scores</h3>
                <div style={{ height: 300 }}>
                  {leaderboard?.entries?.length > 0 ? (
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={leaderboard.entries}>
                        <XAxis dataKey="team.name" stroke="rgba(255,255,255,0.5)" />
                        <YAxis stroke="rgba(255,255,255,0.5)" />
                        <Tooltip cursor={{ fill: 'rgba(255,255,255,0.1)' }} contentStyle={{ backgroundColor: '#252536', border: 'none' }} />
                        <Bar dataKey="score" fill="var(--primary)" radius={[4, 4, 0, 0]} />
                      </BarChart>
                    </ResponsiveContainer>
                  ) : (
                    <div style={{ display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)' }}>
                      No models evaluated yet.
                    </div>
                  )}
                </div>
              </div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '40px', marginTop: '40px' }}>
              <div className="glass-panel">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                  <h3>Detailed Leaderboard</h3>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <span style={{ padding: '4px 12px', background: 'var(--primary)', color: 'black', borderRadius: '12px', fontSize: '12px', fontWeight: 'bold' }}>Public</span>
                    <span style={{ padding: '4px 12px', background: 'rgba(255,255,255,0.1)', color: 'white', borderRadius: '12px', fontSize: '12px' }}>Private (Hidden)</span>
                  </div>
                </div>
                {leaderboard?.entries?.length > 0 ? (
                  <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                    <thead>
                      <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.1)', textAlign: 'left' }}>
                        <th style={{ padding: '16px 8px', color: 'var(--text-muted)' }}>Rank</th>
                        <th style={{ padding: '16px 8px', color: 'var(--text-muted)' }}>Team</th>
                        <th style={{ padding: '16px 8px', color: 'var(--text-muted)' }}>Members</th>
                        <th style={{ padding: '16px 8px', color: 'var(--text-muted)' }}>Score</th>
                      </tr>
                    </thead>
                    <tbody>
                      {leaderboard.entries.map((entry: any) => (
                        <tr key={entry.team.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                          <td style={{ padding: '16px 8px', fontWeight: 'bold', fontSize: '18px' }}>#{entry.rank}</td>
                          <td style={{ padding: '16px 8px' }}>{entry.team.name}</td>
                          <td style={{ padding: '16px 8px' }}>
                            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                              {entry.team.members?.map((m: any) => (
                                <a key={m.id} href={m.link} style={{ color: 'var(--primary)', textDecoration: 'none', fontSize: '14px', background: 'rgba(0,196,159,0.1)', padding: '2px 8px', borderRadius: '12px' }}>
                                  @{m.name}
                                </a>
                              ))}
                            </div>
                          </td>
                          <td style={{ padding: '16px 8px', color: 'var(--primary)', fontWeight: 'bold' }}>{entry.score.toFixed(4)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                ) : (
                  <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
                    No evaluations completed yet.
                  </div>
                )}
              </div>
            </div>
          </>
        ) : activeTab === 'dataset' ? (
          <div className="glass-panel" style={{ minHeight: '400px' }}>
            <h2 style={{ marginBottom: '24px' }}>Dataset Gallery</h2>
            {datasetLoading ? (
              <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>Loading dataset...</div>
            ) : datasetImages.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>No images found.</div>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '16px' }}>
                {datasetImages.map(img => (
                  <div key={img.id} style={{ background: 'rgba(255,255,255,0.05)', borderRadius: '12px', overflow: 'hidden', border: '1px solid rgba(255,255,255,0.08)' }}>
                    <img src={`http://localhost:8000${img.url}`} alt={`img-${img.id}`} style={{ width: '100%', height: '140px', objectFit: 'cover' }} />
                    <div style={{ padding: '12px', fontSize: '13px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ fontWeight: '500', color: 'white', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: '80px' }}>{img.label || 'None'}</span>
                      <span style={{ color: img.status === 'verified' ? '#00C49F' : img.status === 'rejected' ? '#ef4444' : 'var(--text-muted)', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>{img.status}</span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : activeTab === 'teams' ? (
          <div className="glass-panel" style={{ minHeight: '400px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
              <h2>Team Management</h2>
              {role === 'host' && (
                <div style={{ display: 'flex', gap: '12px' }}>
                  <label className="btn-secondary" style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', padding: '10px 20px', width: 'auto', cursor: 'pointer' }}>
                    <Upload size={16} /> Bulk Import (CSV)
                    <input type="file" accept=".csv" style={{ display: 'none' }} onChange={handleBulkImport} />
                  </label>
                  <button className="btn-primary" style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', padding: '10px 20px', width: 'auto' }} onClick={() => setShowCreateTeam(true)}>
                    + Create Team
                  </button>
                </div>
              )}
            </div>
            {teams.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
                No teams created yet. {role === 'host' ? 'Create one to get started!' : ''}
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {teams.map((t) => (
                  <div key={t.id} style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '12px', padding: '20px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                      <div>
                        <h3 style={{ margin: 0, fontSize: '18px' }}>{t.name}</h3>
                        <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Team ID: {t.id} • {t.members?.length || 0} member(s)</span>
                      </div>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <div style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
                          <select 
                            className="input-field" 
                            style={{ padding: '4px 8px', fontSize: '12px', width: 'auto', background: 'rgba(255,255,255,0.05)', color: 'white', border: '1px solid rgba(255,255,255,0.2)' }}
                            value={teamExportFormats[t.id] || 'csv'}
                            onChange={(e) => setTeamExportFormats({...teamExportFormats, [t.id]: e.target.value})}
                          >
                            <option value="csv">CSV</option>
                            <option value="yolo">YOLO</option>
                            <option value="coco">COCO</option>
                          </select>
                          <button className="btn-secondary" style={{ padding: '6px 12px', fontSize: '12px', width: 'auto', display: 'inline-flex', alignItems: 'center', gap: '4px' }} onClick={() => exportTeamDataset(t.id)}>
                            <Download size={14} /> Export Dataset
                          </button>
                        </div>
                        {role === 'host' && (
                          <>
                            <button className="btn-secondary" style={{ padding: '6px 12px', fontSize: '12px', width: 'auto' }} onClick={() => fetchUnassigned(t.id)}>
                              + Add Member
                            </button>
                            <button className="btn-danger" style={{ padding: '6px 12px', fontSize: '12px', width: 'auto' }} onClick={() => deleteTeam(t.id)}>
                              Delete
                            </button>
                          </>
                        )}
                      </div>
                    </div>
                    {/* Members list */}
                    {t.members && t.members.length > 0 ? (
                      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                        {t.members.map((m: any) => (
                          <div key={m.id} style={{ display: 'flex', alignItems: 'center', gap: '6px', background: 'rgba(0,196,159,0.1)', padding: '4px 12px', borderRadius: '20px', fontSize: '14px' }}>
                            <span style={{ color: 'var(--primary)' }}>@{m.fullname || m.name || m.email || m.id}</span>
                            {role === 'host' && (
                              <span style={{ color: '#ef4444', cursor: 'pointer', fontSize: '16px', marginLeft: '4px' }} onClick={() => removeMemberFromTeam(t.id, m.id)} title="Remove member">×</span>
                            )}
                          </div>
                        ))}
                      </div>
                    ) : (
                      <span style={{ color: 'var(--text-muted)', fontSize: '14px' }}>No members yet — add participants to this team</span>
                    )}

                    {/* Validation Progress Bar */}
                    {role === 'host' && dashboard?.team_info?.items && (() => {
                      const stats = dashboard.team_info.items.find((item: any) => item.id === t.id)?.stats || { total: 0, verified: 0 };
                      const total = stats.total || 0;
                      const verified = stats.verified || 0;
                      const pct = total > 0 ? Math.round((verified / total) * 100) : 0;
                      return (
                        <div style={{ marginTop: '20px' }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px', fontSize: '13px' }}>
                            <span style={{ color: 'var(--text-muted)' }}>Validation Progress</span>
                            <span style={{ color: 'var(--primary)', fontWeight: 'bold' }}>{verified} / {total} Images ({pct}%)</span>
                          </div>
                          <div style={{ width: '100%', height: '8px', background: 'rgba(255,255,255,0.1)', borderRadius: '4px', overflow: 'hidden' }}>
                            <div style={{ width: `${pct}%`, height: '100%', background: 'var(--primary)', transition: 'width 0.3s ease' }}></div>
                          </div>
                        </div>
                      );
                    })()}
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : activeTab === 'cleaner' ? (
          <div className="glass-panel" style={{ minHeight: '400px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
              <h2>Dataset Cleaner</h2>
            </div>
            
            <div style={{ background: 'rgba(255,255,255,0.05)', padding: '24px', borderRadius: '8px', marginBottom: '24px' }}>
              <p style={{ color: 'var(--text-muted)', marginBottom: '16px' }}>Run the dataset cleaning pipeline to scan for duplicates, clean metadata, and optimize storage across all competition datasets before evaluating models.</p>
              
              <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
                <button 
                  className="btn-primary" 
                  style={{ width: 'auto', padding: '12px 24px', display: 'flex', alignItems: 'center', gap: '8px' }}
                  onClick={runCleaner}
                  disabled={cleanerStatus === 'Running Cleaner...'}
                >
                  <Activity size={18} />
                  Trigger Pipeline
                </button>
                <span style={{ color: 'var(--primary)', fontWeight: 'bold' }}>{cleanerStatus}</span>
              </div>
            </div>

            {cleanerStats && (
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' }}>
                <div style={{ background: 'rgba(0,196,159,0.1)', border: '1px solid #00C49F', padding: '24px', borderRadius: '8px' }}>
                  <div style={{ color: '#00C49F', fontSize: '14px', marginBottom: '8px' }}>Storage Freed</div>
                  <div style={{ fontSize: '32px', fontWeight: 'bold', color: 'white' }}>{cleanerStats.freed_mb?.toFixed(2) || 0} MB</div>
                </div>
                <div style={{ background: 'rgba(0,196,159,0.1)', border: '1px solid #00C49F', padding: '24px', borderRadius: '8px' }}>
                  <div style={{ color: '#00C49F', fontSize: '14px', marginBottom: '8px' }}>Files Optimized/Removed</div>
                  <div style={{ fontSize: '32px', fontWeight: 'bold', color: 'white' }}>{cleanerStats.files_removed || 0}</div>
                </div>
              </div>
            )}
          </div>
        ) : activeTab === 'settings' ? (
          <div className="glass-panel" style={{ minHeight: '400px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '32px' }}>
              <Settings size={24} color="var(--primary)" />
              <h2 style={{ margin: 0 }}>Competition Settings</h2>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '32px' }}>
              <div>
                <h3 style={{ marginBottom: '16px', fontSize: '16px' }}>Label Configuration</h3>
                <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginBottom: '12px' }}>Comma-separated list of valid labels for image classification.</p>
                <label>Available Labels</label>
                <input
                  type="text"
                  className="input-field"
                  placeholder="e.g., Healthy, Blight, Rust, Weed"
                  value={configLabels || (dashboard?.configuration?.labels || []).join(', ')}
                  onChange={(e) => setConfigLabels(e.target.value)}
                />
              </div>
              <div>
                <h3 style={{ marginBottom: '16px', fontSize: '16px' }}>Validation Threshold</h3>
                <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginBottom: '12px' }}>How many votes are needed before an image is marked as verified.</p>
                <label>Max Validations</label>
                <input
                  type="number"
                  className="input-field"
                  min="1"
                  max="10"
                  value={configThreshold || dashboard?.configuration?.max_validations || '1'}
                  onChange={(e) => setConfigThreshold(e.target.value)}
                />
              </div>
            </div>

            <div style={{ display: 'flex', gap: '12px', marginTop: '16px' }}>
              <button className="btn-accent" style={{ width: 'auto', padding: '10px 24px' }} onClick={saveConfig} disabled={savingConfig}>
                {savingConfig ? 'Saving...' : 'Save Configuration'}
              </button>
            </div>

            <div style={{ marginTop: '40px', padding: '20px', background: 'rgba(255,255,255,0.03)', borderRadius: '12px', border: '1px solid var(--border)' }}>
              <h3 style={{ marginBottom: '12px', fontSize: '16px' }}>Current Configuration</h3>
              <div style={{ display: 'flex', gap: '24px', flexWrap: 'wrap' }}>
                <div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '12px', marginBottom: '4px', textTransform: 'uppercase' }}>Labels</div>
                  <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                    {(dashboard?.configuration?.labels || []).map((l: string) => (
                      <span key={l} className="badge badge-primary">{l}</span>
                    ))}
                    {(dashboard?.configuration?.labels || []).length === 0 && <span style={{ color: 'var(--text-muted)' }}>Not configured</span>}
                  </div>
                </div>
                <div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '12px', marginBottom: '4px', textTransform: 'uppercase' }}>Validation Threshold</div>
                  <span className="badge badge-accent">{dashboard?.configuration?.max_validations || 1} vote(s)</span>
                </div>
                <div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '12px', marginBottom: '4px', textTransform: 'uppercase' }}>Phase</div>
                  <span className="badge badge-warning" style={{ textTransform: 'capitalize' }}>{dashboard?.phase_info?.current_phase || 'creation'}</span>
                </div>
              </div>
            </div>
          </div>
        ) : activeTab === 'models' ? (
          <div className="glass-panel" style={{ minHeight: '400px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
              <h2>Model Submissions</h2>
              {role === 'participant' && (
                <div>
                  <input 
                    type="file" 
                    id="model-upload" 
                    style={{ display: 'none' }} 
                    onChange={uploadModel} 
                    accept=".zip,.tar,.gz,.h5"
                  />
                  <label 
                    htmlFor="model-upload" 
                    className="btn-primary" 
                    style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', cursor: 'pointer', padding: '10px 20px', width: 'auto' }}
                  >
                    <Upload size={18} />
                    {uploading ? 'Uploading...' : 'Submit New Model'}
                  </label>
                </div>
              )}
            </div>

            {role === 'participant' && dashboard.phase_info?.current_phase !== 'evaluation' && (
              <div style={{ background: 'rgba(255,187,40,0.1)', border: '1px solid #FFBB28', color: '#FFBB28', padding: '16px', borderRadius: '8px', marginBottom: '24px' }}>
                Note: The competition is currently in the <strong>{dashboard.phase_info?.current_phase}</strong> phase. Models can only be submitted during the <strong>evaluation</strong> phase.
              </div>
            )}
            {role === 'host' && dashboard.phase_info?.current_phase !== 'evaluation' && (
              <div style={{ background: 'rgba(255,187,40,0.1)', border: '1px solid #FFBB28', color: '#FFBB28', padding: '16px', borderRadius: '8px', marginBottom: '24px' }}>
                Note: The competition is currently in the <strong>{dashboard.phase_info?.current_phase}</strong> phase. Advance to the evaluation phase on the Dashboard tab to enable team submissions.
              </div>
            )}

            {models.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
                No models have been submitted yet.
              </div>
            ) : (
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.1)', textAlign: 'left' }}>
                    <th style={{ padding: '16px 8px', color: 'var(--text-muted)' }}>Version</th>
                    <th style={{ padding: '16px 8px', color: 'var(--text-muted)' }}>Filename</th>
                    <th style={{ padding: '16px 8px', color: 'var(--text-muted)' }}>Status</th>
                    <th style={{ padding: '16px 8px', color: 'var(--text-muted)' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {models.map((m, index) => (
                    <tr key={m.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                      <td style={{ padding: '16px 8px' }}>v{index + 1}</td>
                      <td style={{ padding: '16px 8px' }}>{m.docker_img_filepath?.split('/').pop() || 'model.zip'}</td>
                      <td style={{ padding: '16px 8px' }}>
                        <span style={{ 
                          background: 'rgba(255,255,255,0.1)', 
                          color: 'white',
                          padding: '4px 8px', 
                          borderRadius: '4px',
                          fontSize: '12px',
                          textTransform: 'uppercase'
                        }}>
                          SUBMITTED
                        </span>
                      </td>
                        <td style={{ padding: '16px 8px', display: 'flex', gap: '8px' }}>
                          <button 
                            className="btn-outline"
                            onClick={() => viewHistory(m.id)}
                            style={{ padding: '6px 14px', fontSize: '13px', display: 'inline-flex', alignItems: 'center', gap: '6px' }}
                          >
                            <Activity size={14} /> History
                          </button>
                          {role === 'host' && (
                            <button 
                              className="btn-outline"
                              onClick={() => { setEvalModalModelId(m.id); setEvalProtocol('standard'); setEvalResult(''); }}
                              style={{ padding: '6px 14px', fontSize: '13px', display: 'inline-flex', alignItems: 'center', gap: '6px' }}
                            >
                              <Play size={14} /> Evaluate
                            </button>
                          )}
                        </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        ) : null}
      </div>

      {/* Phase Advance Confirmation */}
      {showPhaseConfirm && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '460px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' }}>
              <AlertTriangle size={24} color="var(--warning)" />
              <h3 style={{ margin: 0 }}>Advance Phase</h3>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '20px', padding: '16px', borderRadius: '10px', background: 'rgba(255,255,255,0.03)', border: '1px solid var(--border)' }}>
              <span className="badge badge-primary" style={{ textTransform: 'capitalize' }}>{dashboard?.phase_info?.current_phase}</span>
              <ChevronRight size={16} color="var(--text-muted)" />
              <span className="badge badge-accent" style={{ textTransform: 'capitalize' }}>
                {PHASE_ORDER[PHASE_ORDER.indexOf(dashboard?.phase_info?.current_phase || 'creation') + 1] || 'completed'}
              </span>
            </div>
            <div className="alert alert-warning" style={{ marginBottom: '20px' }}>
              <AlertTriangle size={14} style={{ display: 'inline', marginRight: '6px', verticalAlign: 'middle' }} />
              {PHASE_WARNINGS[dashboard?.phase_info?.current_phase || 'creation'] || 'This action cannot be undone.'}
            </div>
            <div style={{ display: 'flex', gap: '12px' }}>
              <button className="btn-secondary" onClick={() => setShowPhaseConfirm(false)} style={{ flex: 1 }}>Cancel</button>
              <button className="btn-accent" onClick={advancePhase} style={{ flex: 1 }}>Confirm Advance</button>
            </div>
          </div>
        </div>
      )}

      {/* Create Team Modal */}
      {showCreateTeam && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '400px' }}>
            <h3 style={{ marginBottom: '24px' }}>Create New Team</h3>
            <div style={{ marginBottom: '24px' }}>
              <label>Team Name</label>
              <input type="text" className="input-field" placeholder="e.g., Alpha Team" value={newTeamName} onChange={(e) => setNewTeamName(e.target.value)} />
            </div>
            <div style={{ display: 'flex', gap: '16px' }}>
              <button className="btn-secondary" onClick={() => setShowCreateTeam(false)}>Cancel</button>
              <button className="btn-primary" disabled={teamActionLoading} onClick={createTeam}>
                {teamActionLoading ? 'Creating...' : 'Create Team'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add Member Modal */}
      {showAddMember !== null && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '450px' }}>
            <h3 style={{ marginBottom: '8px' }}>Add Member to Team</h3>
            <p style={{ color: 'var(--text-muted)', marginBottom: '24px', fontSize: '14px' }}>
              Select an unassigned participant to add to this team.
            </p>
            {unassigned.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
                All participants are already assigned to teams.
              </div>
            ) : (
              <div style={{ maxHeight: '300px', overflowY: 'auto', marginBottom: '16px' }}>
                {unassigned.map((u: any) => (
                  <div key={u.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                    <div>
                      <div style={{ fontWeight: 'bold' }}>{u.fullname}</div>
                      <div style={{ color: 'var(--text-muted)', fontSize: '13px' }}>{u.email}</div>
                    </div>
                    <button className="btn-primary" style={{ padding: '4px 14px', fontSize: '12px', width: 'auto' }} disabled={teamActionLoading} onClick={() => addMemberToTeam(showAddMember, u.id)}>
                      Add
                    </button>
                  </div>
                ))}
              </div>
            )}
            <button className="btn-secondary" onClick={() => setShowAddMember(null)}>Close</button>
          </div>
        </div>
      )}

      {/* Evaluation Protocol Modal */}
      {evalModalModelId !== null && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '500px' }}>
            <h3 style={{ marginBottom: '8px' }}>Run Model Evaluation</h3>
            <p style={{ color: 'var(--text-muted)', marginBottom: '24px', fontSize: '14px' }}>
              Select an evaluation protocol. The model's Docker container will be executed against the validated dataset.
            </p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginBottom: '24px' }}>
              {[
                { value: 'standard', label: 'Standard (80/20 Split)', desc: 'Random 80% train / 20% test split' },
                { value: 'kfold', label: '5-Fold Cross Validation', desc: 'Averages accuracy across 5 unique splits' },
                { value: 'loto', label: 'LOTO (Leave-One-Team-Out)', desc: 'Test on submitting team, train on all others' },
                { value: 'toto', label: 'TOTO (Train-On-One-Team-Only)', desc: 'Train only on submitting team, test on others' },
              ].map((p) => (
                <label key={p.value} style={{ display: 'flex', alignItems: 'flex-start', gap: '12px', padding: '14px', background: evalProtocol === p.value ? 'rgba(0,196,159,0.1)' : 'rgba(255,255,255,0.03)', border: `1px solid ${evalProtocol === p.value ? '#00C49F' : 'rgba(255,255,255,0.08)'}`, borderRadius: '10px', cursor: 'pointer' }}>
                  <input type="radio" name="protocol" value={p.value} checked={evalProtocol === p.value} onChange={() => setEvalProtocol(p.value)} style={{ marginTop: '3px' }} />
                  <div>
                    <div style={{ fontWeight: 'bold', marginBottom: '4px' }}>{p.label}</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: '13px' }}>{p.desc}</div>
                  </div>
                </label>
              ))}
            </div>
            {evalResult && (
              <div style={{ padding: '14px', borderRadius: '8px', marginBottom: '16px', background: evalResult.startsWith('✅') ? 'rgba(0,196,159,0.1)' : 'rgba(239,68,68,0.1)', border: `1px solid ${evalResult.startsWith('✅') ? '#00C49F' : '#ef4444'}`, fontSize: '14px', whiteSpace: 'pre-wrap' }}>
                {evalResult}
              </div>
            )}
            <div style={{ display: 'flex', gap: '16px' }}>
              <button className="btn-secondary" onClick={() => setEvalModalModelId(null)} disabled={evaluating}>Cancel</button>
              <button className="btn-primary" disabled={evaluating} onClick={() => evaluateModel(evalModalModelId!, evalProtocol)} style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Play size={16} />
                {evaluating ? 'Running Docker Container...' : 'Run Evaluation'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* History Modal */}
      {historyModalModelId !== null && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '800px' }}>
            <h3 style={{ marginBottom: '8px' }}>Evaluation History</h3>
            <p style={{ color: 'var(--text-muted)', marginBottom: '24px', fontSize: '14px' }}>
              Past evaluation attempts and execution logs for this model.
            </p>
            {loadingHistory ? (
              <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>Loading history...</div>
            ) : modelHistory.length === 0 ? (
              <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>No evaluation history found.</div>
            ) : (
              <div style={{ maxHeight: '400px', overflowY: 'auto', marginBottom: '24px' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                  <thead>
                    <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.1)', textAlign: 'left' }}>
                      <th style={{ padding: '12px 8px', color: 'var(--text-muted)' }}>Date</th>
                      <th style={{ padding: '12px 8px', color: 'var(--text-muted)' }}>Status</th>
                      <th style={{ padding: '12px 8px', color: 'var(--text-muted)' }}>Score</th>
                      <th style={{ padding: '12px 8px', color: 'var(--text-muted)' }}>Details</th>
                    </tr>
                  </thead>
                  <tbody>
                    {modelHistory.map(h => {
                      const metrics = h.metrics_json ? JSON.parse(h.metrics_json) : null;
                      return (
                        <tr key={h.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                          <td style={{ padding: '12px 8px', fontSize: '13px' }}>
                            {new Date(h.evaluated_at + 'Z').toLocaleString()}
                          </td>
                          <td style={{ padding: '12px 8px' }}>
                            <span className={`badge badge-${h.status === 'completed' ? 'primary' : h.status === 'failed' ? 'error' : 'warning'}`}>
                              {h.status}
                            </span>
                          </td>
                          <td style={{ padding: '12px 8px', fontWeight: 'bold', color: 'var(--primary)' }}>
                            {h.score !== null ? `${(h.score * 100).toFixed(2)}%` : '-'}
                          </td>
                          <td style={{ padding: '12px 8px', fontSize: '12px', color: 'var(--text-muted)' }}>
                            {metrics ? (
                              <div>
                                <div><span style={{ color: 'white' }}>Protocol:</span> {metrics.protocol}</div>
                                {metrics.per_class_accuracy && (
                                  <div style={{ marginTop: '4px' }}>
                                    <span style={{ color: 'white' }}>Per Class:</span>{' '}
                                    {Object.entries(metrics.per_class_accuracy).map(([cls, acc]) => `${cls}: ${((acc as number)*100).toFixed(0)}%`).join(', ')}
                                  </div>
                                )}
                              </div>
                            ) : '-'}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
            <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <button className="btn-secondary" onClick={() => setHistoryModalModelId(null)}>Close</button>
            </div>
          </div>
        </div>
      )}

      {/* Invite Token Modal */}
      {showInviteModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '500px' }}>
            <h3 style={{ marginBottom: '8px' }}>Invitation Token Generated</h3>
            <p style={{ color: 'var(--text-muted)', marginBottom: '16px', fontSize: '14px' }}>
              Share this token with participants. They can paste it in "Join via Invite" on their Dashboard.
            </p>
            <div style={{ position: 'relative', marginBottom: '16px' }}>
              <input
                type="text"
                className="input-field"
                value={inviteTokenValue}
                readOnly
                onClick={(e) => (e.target as HTMLInputElement).select()}
                style={{ paddingRight: '80px', fontFamily: 'monospace', fontSize: '13px' }}
              />
              <button
                className="btn-primary"
                style={{ position: 'absolute', right: '4px', top: '50%', transform: 'translateY(-50%)', padding: '6px 14px', fontSize: '12px', width: 'auto' }}
                onClick={() => {
                  navigator.clipboard.writeText(inviteTokenValue);
                }}
              >
                Copy
              </button>
            </div>
            <p style={{ color: 'var(--text-muted)', fontSize: '12px', marginBottom: '24px' }}>
              In production, an email with this link would be dispatched automatically to the invitees.
            </p>
            <button className="btn-secondary" onClick={() => setShowInviteModal(false)}>Close</button>
          </div>
        </div>
      )}
    </div>
  );
}
