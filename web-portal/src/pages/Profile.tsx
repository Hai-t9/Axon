import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, User, Mail, Phone, Calendar, Shield, Users, Trophy } from 'lucide-react';

export default function Profile() {
  const [profile, setProfile] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const fetchProfile = async () => {
      const token = localStorage.getItem('token');
      if (!token) { navigate('/login'); return; }

      try {
        const res = await fetch('http://localhost:8000/api/v1/register/me', {
          headers: { 'Authorization': `Bearer ${token}` }
        });
        if (res.ok) setProfile(await res.json());
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    fetchProfile();
  }, [navigate]);

  if (loading) return <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 1, color: 'var(--text-muted)' }}>Loading profile...</div>;
  if (!profile) return <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 1, color: 'var(--text-muted)' }}>Could not load profile.</div>;

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
      <header className="header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', cursor: 'pointer' }} onClick={() => navigate('/dashboard')}>
          <ArrowLeft color="var(--primary)" />
          <div className="header-title">My Profile</div>
        </div>
      </header>

      <div className="dashboard-container" style={{ maxWidth: '800px', margin: '0 auto', width: '100%' }}>
        {/* Profile Header */}
        <div className="glass-panel" style={{ display: 'flex', alignItems: 'center', gap: '32px', marginBottom: '32px' }}>
          <div style={{
            width: '100px', height: '100px', borderRadius: '50%',
            background: 'linear-gradient(135deg, var(--primary), #6366f1)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: '40px', fontWeight: 'bold', color: 'white', flexShrink: 0
          }}>
            {profile.fullname?.charAt(0)?.toUpperCase() || '?'}
          </div>
          <div style={{ flex: 1 }}>
            <h1 style={{ margin: '0 0 4px 0', fontSize: '28px' }}>{profile.fullname}</h1>
            <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: '16px' }}>Member since {profile.created_at ? new Date(profile.created_at).toLocaleDateString('en-US', { year: 'numeric', month: 'long' }) : 'N/A'}</p>
          </div>
        </div>

        {/* Info Cards */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginBottom: '32px' }}>
          <div className="glass-panel">
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px' }}>
              <Mail size={20} color="var(--primary)" />
              <span style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Email</span>
            </div>
            <div style={{ fontSize: '16px', fontWeight: '500' }}>{profile.email}</div>
          </div>
          <div className="glass-panel">
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px' }}>
              <Phone size={20} color="var(--primary)" />
              <span style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Phone</span>
            </div>
            <div style={{ fontSize: '16px', fontWeight: '500' }}>{profile.phone || 'Not provided'}</div>
          </div>
          <div className="glass-panel">
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px' }}>
              <Calendar size={20} color="var(--primary)" />
              <span style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Account Created</span>
            </div>
            <div style={{ fontSize: '16px', fontWeight: '500' }}>{profile.created_at ? new Date(profile.created_at).toLocaleDateString() : 'N/A'}</div>
          </div>
          <div className="glass-panel">
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px' }}>
              <Trophy size={20} color="var(--primary)" />
              <span style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Competitions</span>
            </div>
            <div style={{ fontSize: '16px', fontWeight: '500' }}>{profile.competitions?.length || 0} active</div>
          </div>
        </div>

        {/* Competitions & Roles */}
        <div className="glass-panel">
          <h3 style={{ marginBottom: '24px', display: 'flex', alignItems: 'center', gap: '12px' }}>
            <Shield size={22} color="var(--primary)" />
            My Competitions & Roles
          </h3>
          {profile.competitions?.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
              You haven't joined any competitions yet.
            </div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.1)', textAlign: 'left' }}>
                  <th style={{ padding: '12px 8px', color: 'var(--text-muted)' }}>Competition</th>
                  <th style={{ padding: '12px 8px', color: 'var(--text-muted)' }}>Role</th>
                  <th style={{ padding: '12px 8px', color: 'var(--text-muted)' }}>Team</th>
                  <th style={{ padding: '12px 8px', color: 'var(--text-muted)' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {profile.competitions.map((c: any) => (
                  <tr key={c.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                    <td style={{ padding: '16px 8px', fontWeight: 'bold' }}>{c.name}</td>
                    <td style={{ padding: '16px 8px' }}>
                      <span style={{
                        background: c.role === 'host' ? 'rgba(99,102,241,0.2)' : 'rgba(0,196,159,0.2)',
                        color: c.role === 'host' ? '#818cf8' : '#00C49F',
                        padding: '4px 10px', borderRadius: '12px', fontSize: '12px', fontWeight: 'bold', textTransform: 'uppercase'
                      }}>
                        {c.role}
                      </span>
                    </td>
                    <td style={{ padding: '16px 8px' }}>
                      {c.team ? (
                        <span style={{ color: 'var(--primary)', background: 'rgba(0,196,159,0.1)', padding: '2px 8px', borderRadius: '12px', fontSize: '14px' }}>
                          {c.team.name}
                        </span>
                      ) : (
                        <span style={{ color: 'var(--text-muted)', fontSize: '14px' }}>—</span>
                      )}
                    </td>
                    <td style={{ padding: '16px 8px' }}>
                      <button
                        className="btn-primary"
                        style={{ padding: '4px 12px', fontSize: '12px', width: 'auto' }}
                        onClick={() => navigate(`/competitions/${c.id}`)}
                      >
                        View
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
