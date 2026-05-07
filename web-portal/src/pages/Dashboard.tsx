import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { LogOut, Activity, Plus, Link as LinkIcon, User } from 'lucide-react';

export default function Dashboard() {
  const [competitions, setCompetitions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  
  // Modal states
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showJoinModal, setShowJoinModal] = useState(false);
  const [newCompName, setNewCompName] = useState('');
  const [newCompDesc, setNewCompDesc] = useState('');
  const [inviteToken, setInviteToken] = useState('');
  const [actionLoading, setActionLoading] = useState(false);
  const [actionError, setActionError] = useState('');

  const navigate = useNavigate();

  useEffect(() => {
    fetchCompetitions();
  }, []);

  const fetchCompetitions = async () => {
    const token = localStorage.getItem('token');
    if (!token) {
      navigate('/login');
      return;
    }

    try {
      const res = await fetch('http://localhost:8000/api/v1/competitions', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      if (!res.ok) {
        if (res.status === 401) {
          navigate('/login');
          return;
        }
        throw new Error('Failed to fetch competitions');
      }
      const data = await res.json();
      setCompetitions(data.items || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    navigate('/login');
  };

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setActionLoading(true);
    setActionError('');
    const token = localStorage.getItem('token');
    try {
      const res = await fetch('http://localhost:8000/api/v1/competitions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ name: newCompName, description: newCompDesc })
      });
      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.detail || 'Failed to create competition');
      }
      setShowCreateModal(false);
      setNewCompName('');
      setNewCompDesc('');
      fetchCompetitions();
    } catch (err: any) {
      setActionError(err.message);
    } finally {
      setActionLoading(false);
    }
  };

  const handleJoin = async (e: React.FormEvent) => {
    e.preventDefault();
    setActionLoading(true);
    setActionError('');
    const token = localStorage.getItem('token');
    try {
      const res = await fetch(`http://localhost:8000/api/v1/invitations/join?token=${encodeURIComponent(inviteToken)}`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      if (!res.ok) throw new Error('Failed to join. Invalid or expired token.');
      setShowJoinModal(false);
      setInviteToken('');
      fetchCompetitions();
    } catch (err: any) {
      setActionError(err.message);
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', position: 'relative' }}>
      <header className="header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <Activity color="var(--primary)" />
          <div className="header-title">Axon Dashboard</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <button
            onClick={() => navigate('/profile')}
            style={{ background: 'transparent', border: '1px solid rgba(255,255,255,0.15)', color: 'white', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px', padding: '6px 14px', borderRadius: '8px' }}
          >
            <User size={16} /> Profile
          </button>
          <button 
            onClick={handleLogout}
            style={{ background: 'transparent', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px' }}
          >
            <LogOut size={18} /> Logout
          </button>
        </div>
      </header>

      <div className="dashboard-container">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
          <h2>My Competitions</h2>
          <div style={{ display: 'flex', gap: '16px' }}>
            <button className="btn-secondary" onClick={() => setShowJoinModal(true)} style={{ width: 'auto', display: 'flex', alignItems: 'center', gap: '8px', padding: '8px 16px' }}>
              <LinkIcon size={18} /> Join via Invite
            </button>
            <button className="btn-primary" onClick={() => setShowCreateModal(true)} style={{ width: 'auto', display: 'flex', alignItems: 'center', gap: '8px', padding: '8px 16px' }}>
              <Plus size={18} /> Create New
            </button>
          </div>
        </div>

        {error && <div className="error-msg">{error}</div>}

        {loading ? (
          <p style={{ color: 'var(--text-muted)' }}>Loading competitions...</p>
        ) : competitions.length === 0 ? (
          <div className="glass-panel" style={{ textAlign: 'center', padding: '60px' }}>
            <p style={{ color: 'var(--text-muted)', fontSize: '18px', marginBottom: '16px' }}>No competitions found. Create or join one!</p>
            <div style={{ display: 'flex', gap: '16px', justifyContent: 'center' }}>
              <button className="btn-primary" onClick={() => setShowCreateModal(true)} style={{ width: 'auto', padding: '8px 24px' }}>Create Competition</button>
              <button className="btn-secondary" onClick={() => setShowJoinModal(true)} style={{ width: 'auto', padding: '8px 24px' }}>Join Competition</button>
            </div>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '20px' }}>
            {competitions.map((comp) => (
              <div key={comp.id} className="card" style={{ display: 'flex', flexDirection: 'column' }}>
                <h3 style={{ marginBottom: '8px', color: 'var(--primary)' }}>{comp.name}</h3>
                <p style={{ color: 'var(--text-muted)', fontSize: '14px', marginBottom: '16px', flex: 1 }}>{comp.description}</p>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '12px', background: 'rgba(255,255,255,0.1)', padding: '4px 8px', borderRadius: '4px', textTransform: 'capitalize' }}>
                    Status: {comp.current_phase || 'Setup'}
                  </span>
                  <button 
                    className="btn-primary" 
                    style={{ padding: '6px 12px', fontSize: '12px', width: 'auto' }}
                    onClick={() => navigate(`/competitions/${comp.id}`)}
                  >
                    View Details
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Create Competition Modal */}
      {showCreateModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div className="glass-panel" style={{ width: '100%', maxWidth: '400px' }}>
            <h3 style={{ marginBottom: '24px' }}>Create Competition</h3>
            {actionError && <div className="error-msg" style={{ marginBottom: '16px' }}>{actionError}</div>}
            <form onSubmit={handleCreate}>
              <div style={{ marginBottom: '16px' }}>
                <label>Name</label>
                <input type="text" className="input-field" value={newCompName} onChange={(e) => setNewCompName(e.target.value)} required />
              </div>
              <div style={{ marginBottom: '24px' }}>
                <label>Description</label>
                <textarea className="input-field" rows={3} value={newCompDesc} onChange={(e) => setNewCompDesc(e.target.value)} required />
              </div>
              <div style={{ display: 'flex', gap: '16px' }}>
                <button type="button" className="btn-secondary" onClick={() => setShowCreateModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={actionLoading}>{actionLoading ? 'Creating...' : 'Create'}</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Join Competition Modal */}
      {showJoinModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div className="glass-panel" style={{ width: '100%', maxWidth: '400px' }}>
            <h3 style={{ marginBottom: '24px' }}>Join Competition</h3>
            {actionError && <div className="error-msg" style={{ marginBottom: '16px' }}>{actionError}</div>}
            <form onSubmit={handleJoin}>
              <div style={{ marginBottom: '24px' }}>
                <label>Invitation Token</label>
                <input type="text" className="input-field" placeholder="Paste your invite token here" value={inviteToken} onChange={(e) => setInviteToken(e.target.value)} required />
              </div>
              <div style={{ display: 'flex', gap: '16px' }}>
                <button type="button" className="btn-secondary" onClick={() => setShowJoinModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={actionLoading}>{actionLoading ? 'Joining...' : 'Join'}</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
