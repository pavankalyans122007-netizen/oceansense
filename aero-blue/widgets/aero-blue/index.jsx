import { React, run } from 'uebersicht';
import runtime from './runtime.json';
import { commandFor, parsePayload, percentage, formatBytes, temperature, weatherSymbol, focusRemaining, clockDuration, monthCells, panelPosition } from './lib/helpers.js';

const pollCommand = commandFor(runtime, ['widget-data']);
export const command = pollCommand || "printf '%s' '{\"error\":\"Install widgets from Aero Blue Control Center or run aero.py widgets install --yes.\"}'";
export const refreshFrequency = 15000;

export const className = `
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  color: #164669;
  font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
  font-size: 13px;
  -webkit-font-smoothing: antialiased;

  * { box-sizing: border-box; }
  .glass-panel {
    position: absolute; pointer-events: auto; padding: 20px; overflow: hidden;
    border: 1px solid rgba(255,255,255,.86); border-radius: 25px;
    background: linear-gradient(145deg,rgba(244,251,255,.94),rgba(205,238,255,.80) 65%,rgba(168,216,255,.84));
    box-shadow: 0 12px 30px rgba(11,65,105,.14), inset 0 1px 0 rgba(255,255,255,.96);
    backdrop-filter: blur(24px); -webkit-backdrop-filter: blur(24px);
  }
  .glass-panel::before {
    content: ''; position: absolute; pointer-events: none; top: -80px; right: -42px;
    width: 195px; height: 150px; border-radius: 50%; transform: rotate(-18deg);
    background: linear-gradient(180deg,rgba(255,255,255,.48),rgba(255,255,255,0));
  }
  .opaque .glass-panel { background: #e4f4ff; backdrop-filter: none; -webkit-backdrop-filter: none; }
  .animated .glass-panel { animation: arrive .28s ease-out both; }
  @keyframes arrive { from { opacity: 0; transform: translateY(3px); } to { opacity: 1; transform: none; } }
  header { display: flex; align-items: center; justify-content: space-between; gap: 10px; margin-bottom: 14px; position: relative; }
  h2 { font-size: 11px; letter-spacing: 1.8px; text-transform: uppercase; font-weight: 700; margin: 0; color: #286b94; }
  h3 { margin: 0 0 5px; font-size: 16px; font-weight: 600; }
  p { margin: 6px 0; line-height: 1.5; }
  .muted { color: #42657c; font-size: 12px; line-height: 1.5; }
  .tag { border: 1px solid rgba(68,144,188,.25); background: rgba(255,255,255,.55); border-radius: 10px; padding: 3px 8px; font-size: 10px; white-space: nowrap; }
  .divider { height: 1px; background: rgba(36,120,184,.16); margin: 14px 0; }
  .time { font-size: 47px; font-weight: 300; letter-spacing: -2px; font-variant-numeric: tabular-nums; white-space: nowrap; line-height: 1.1; color: #174f7b; }
  .date { margin-top: 9px; font-size: 13px; }
  .weather-main { display: flex; justify-content: space-between; gap: 12px; align-items: center; }
  .temperature { font-size: 42px; font-weight: 300; letter-spacing: -1px; line-height: 1.2; }
  .weather-symbol { font-size: 45px; color: #217cae; text-shadow: 0 2px 0 #fff; }
  .forecast { display: flex; gap: 8px; justify-content: space-between; margin-top: 14px; text-align: center; font-size: 11px; }
  .forecast > div { flex: 1; }
  .forecast-symbol { font-size: 22px; margin: 4px 0; }
  .metric { margin-bottom: 12px; }
  .metric:last-child { margin-bottom: 0; }
  .metric-title { display: flex; justify-content: space-between; gap: 8px; margin-bottom: 6px; }
  .metric-value { font-weight: 600; font-variant-numeric: tabular-nums; }
  .meter { height: 5px; border-radius: 10px; background: rgba(36,120,184,.13); overflow: hidden; }
  .meter > span { display: block; height: 100%; border-radius: 10px; background: linear-gradient(90deg,#2478b8,#31a8bb); }
  .album { display: flex; gap: 12px; align-items: center; margin-bottom: 15px; }
  .album-art { flex: 0 0 52px; width: 52px; height: 52px; object-fit: cover; border-radius: 13px; border: 1px solid #fff; background: linear-gradient(135deg,#f4fbff,#65c7f7); display: flex; align-items: center; justify-content: center; font-size: 27px; }
  .track-info { min-width: 0; }
  .track-title { font-size: 15px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .controls { display: flex; gap: 8px; align-items: center; }
  button, input, select { font: inherit; color: inherit; }
  button { cursor: pointer; border: 1px solid rgba(36,120,184,.25); border-radius: 11px; padding: 7px 12px; background: linear-gradient(#fff,#dcf0ff); box-shadow: 0 1px 2px rgba(36,120,184,.07); }
  button:hover { background: #f4fbff; border-color: #2478b8; }
  button:disabled { opacity: .55; cursor: wait; }
  button:focus-visible, input:focus-visible, select:focus-visible { outline: 2px solid #2478b8; outline-offset: 3px; }
  button.primary { background: linear-gradient(#2b8fca,#2478b8); border-color: #2478b8; color: white; }
  button.small { padding: 4px 8px; font-size: 11px; }
  .calendar-grid { display: grid; grid-template-columns: repeat(7,1fr); gap: 4px; text-align: center; font-size: 12px; }
  .calendar-grid > span { padding: 5px 0; min-width: 0; }
  .calendar-grid .weekday { font-size: 10px; color: #42657c; padding-bottom: 8px; }
  .calendar-grid .today { background: #2478b8; color: #fff; border-radius: 9px; font-weight: 600; }
  .event { margin: 10px 0; padding-left: 9px; border-left: 3px solid #2d9bc4; }
  .event-title { font-weight: 600; overflow-wrap: anywhere; }
  .tasks { margin: 12px 0; padding: 0; list-style: none; max-height: 160px; overflow-y: auto; }
  .tasks li { display: flex; align-items: flex-start; gap: 8px; padding: 6px 0; }
  .tasks label { flex: 1; min-width: 0; display: flex; gap: 8px; align-items: flex-start; }
  .tasks input { accent-color: #2478b8; margin: 3px 0 0; }
  .task-text { overflow-wrap: anywhere; line-height: 1.5; }
  .completed .task-text { text-decoration: line-through; color: #557284; }
  .delete-task { padding: 0 4px; border: 0; background: transparent; font-size: 17px; box-shadow: none; }
  .task-form { display: flex; gap: 6px; }
  .task-form input { width: 100%; min-width: 0; background: rgba(255,255,255,.65); border: 1px solid rgba(36,120,184,.25); border-radius: 10px; padding: 8px 10px; }
  .focus { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
  .focus-time { font-size: 25px; font-weight: 300; font-variant-numeric: tabular-nums; }
  .notice { position: absolute; left: 24px; bottom: 45px; max-width: 420px; border: 1px solid #fff; padding: 14px 18px; border-radius: 16px; background: #e4f4ff; pointer-events: auto; line-height: 1.5; box-shadow: 0 5px 20px #1234; }
  .error { color: #794719; }
  .footnote { font-size: 10px; color: #42657c; margin-top: 10px; line-height: 1.5; }
  @media (prefers-reduced-motion: reduce) { .animated .glass-panel { animation: none; } }
  @media (prefers-reduced-transparency: reduce) { .glass-panel { background: #e4f4ff; backdrop-filter: none; -webkit-backdrop-filter: none; } }
  @media (prefers-contrast: more) { .glass-panel { background: #f4fbff; border-color: #2478b8; } .muted,.footnote { color: #164669; } }
  @media (prefers-color-scheme: dark) {
    color: #e3f4ff;
    .glass-panel { background: linear-gradient(145deg,rgba(21,58,84,.96),rgba(16,45,67,.92)); border-color: rgba(168,216,255,.38); }
    .opaque .glass-panel { background: #153a54; }
    h2,.time,.weather-symbol { color: #a8d8ff; }
    .muted,.footnote,.calendar-grid .weekday { color: #b6d5e8; }
    .tag { background: rgba(168,216,255,.12); border-color: rgba(168,216,255,.3); }
    button { background: #235778; border-color: #6ca6ca; }
    button:hover { background: #2c668a; }
    .task-form input { background: #174464; border-color: #6ca6ca; }
    .notice { background: #153a54; }
    .error { color: #ffd4a5; }
    .completed .task-text { color: #b6d5e8; }
  }
`;

function Panel({ name, label, tag, settings, children }) {
  const config = settings.widgets && settings.widgets[name];
  if (!config || !config.enabled) return null;
  return <section className="glass-panel" style={panelPosition(config)} aria-label={label}>
    <header><h2>{label}</h2>{tag ? <span className="tag">{tag}</span> : null}</header>
    {children}
  </section>;
}

function Clock({ now, settings }) {
  const width = panelPosition((settings.widgets || {}).clock).width;
  return <Panel name="clock" label="Aero clock" tag="Local time" settings={settings}>
    <div className="time" style={{ fontSize: Math.min(47, Math.max(24, (width - 40) / (settings.clock24h ? 4.2 : 6.5))) }}>{now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: !settings.clock24h })}</div>
    <div className="date">{now.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' })}</div>
  </Panel>;
}

function Weather({ data = {}, settings }) {
  const weather = settings.weather || {};
  const units = data.unit || weather.units;
  return <Panel name="weather" label="Weather" tag={data.stale ? 'Saved reading' : null} settings={settings}>
    <h3>{data.city || weather.city || 'Choose your city'}</h3>
    {data.available ? <>
      <div className="weather-main"><div><div className="temperature">{temperature(data.temperature, units)}</div><div className="muted">{data.condition || 'Current weather'}</div></div><div className="weather-symbol" aria-hidden="true">{weatherSymbol(data.code)}</div></div>
      <div className="forecast">{(data.forecast || []).slice(0, 3).map(day => <div key={day.date}>
        <div>{new Date(`${day.date}T12:00:00`).toLocaleDateString([], { weekday: 'short' })}</div>
        <div className="forecast-symbol" aria-hidden="true">{weatherSymbol(day.code)}</div>
        <div>{temperature(day.high, units)} / {temperature(day.low, units)}</div>
      </div>)}</div>
      <p className="footnote">Open-Meteo · {data.updatedAt ? `Updated ${new Date(data.updatedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}` : 'Update time unavailable'}</p>
      {data.stale ? <p className="muted">Offline. Last successful reading shown.</p> : null}
    </> : <p className="muted">{data.error || 'Set a city and its coordinates in Control Center. Weather needs an internet connection.'}</p>}
  </Panel>;
}

function Metric({ label, value, detail }) {
  const percent = typeof value === 'number' && Number.isFinite(value) ? Math.max(0, Math.min(100, value)) : null;
  return <div className="metric"><div className="metric-title"><span>{label}</span><span className="metric-value">{percentage(value)}</span></div>
    {percent !== null ? <div className="meter" role="meter" aria-label={label} aria-valuenow={Math.round(percent)} aria-valuemin={0} aria-valuemax={100}><span style={{ width: `${percent}%` }} /></div> : null}
    {detail ? <div className="footnote">{detail}</div> : null}
  </div>;
}

function System({ data = {}, settings }) {
  return <Panel name="system" label="System" tag="Live · 15 sec" settings={settings}>
    {data.error ? <p className="muted">{data.error}</p> : null}
    <Metric label="CPU" value={data.cpuPercent} />
    <Metric label="Memory" value={data.memoryPercent} detail={data.memoryTotalBytes ? `${formatBytes(data.memoryUsedBytes)} / ${formatBytes(data.memoryTotalBytes)}` : null} />
    <Metric label={data.batteryCharging ? 'Battery · charging' : 'Battery'} value={data.batteryPercent} />
    <Metric label="Storage" value={data.diskPercent} detail={data.diskTotalBytes ? `${formatBytes(data.diskUsedBytes)} / ${formatBytes(data.diskTotalBytes)}` : null} />
    {data.batteryPercent === null ? <p className="footnote">Battery data is unavailable on devices without a battery.</p> : null}
  </Panel>;
}

function Music({ data = {}, settings, act, busy }) {
  const allowed = settings.permissions && settings.permissions.music;
  const art = typeof data.artwork === 'string' && /^(data:image\/(png|jpeg);base64,|https:\/\/)/.test(data.artwork) ? data.artwork : null;
  return <Panel name="music" label="Music" tag={data.playing ? 'Playing' : null} settings={settings}>
    {!allowed || data.authorized === false ? <p className="muted">Enable Music access in Control Center, then approve macOS Automation access when prompted.</p> : <>
      <div className="album">{art ? <img className="album-art" alt="Album artwork" src={art} /> : <div className="album-art" aria-hidden="true">♫</div>}<div className="track-info"><div className="track-title">{data.title || 'No track playing'}</div><div className="muted">{data.artist || 'Apple Music'}</div></div></div>
      <div className="controls"><button className="primary" disabled={busy || !data.available} onClick={() => act(['music', 'playpause'])}>{data.playing ? 'Pause' : 'Play'}</button><button disabled={busy || !data.available} onClick={() => act(['music', 'next'])} aria-label="Next track">Next ›</button></div>
      {data.error ? <p className="muted">{data.error}</p> : null}
    </>}
  </Panel>;
}

function Calendar({ data = {}, settings, now }) {
  return <Panel name="calendar" label="Calendar" tag={now.toLocaleDateString([], { month: 'short', year: 'numeric' })} settings={settings}>
    <div className="calendar-grid" aria-label={now.toLocaleDateString([], { month: 'long', year: 'numeric' })}>
      {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day, index) => <span key={`week${index}`} className="weekday" aria-hidden="true">{day}</span>)}
      {monthCells(now).map((day, index) => <span key={index} className={day === now.getDate() ? 'today' : ''} aria-current={day === now.getDate() ? 'date' : undefined}>{day}</span>)}
    </div>
    <div className="divider" />
    {data.authorized ? <>
      {(data.events || []).slice(0, 3).map((event, index) => <div className="event" key={event.id || index}><div className="event-title">{event.title || 'Untitled event'}</div><div className="muted">{event.allDay ? 'All day' : new Date(event.start).toLocaleString([], { weekday: 'short', hour: '2-digit', minute: '2-digit' })}</div></div>)}
      {!(data.events || []).length ? <p className="muted">No upcoming events.</p> : null}
    </> : <p className="muted">Your calendar stays private until you grant access in Control Center.</p>}
    {data.error ? <p className="muted">{data.error}</p> : null}
  </Panel>;
}

function Productivity({ data = {}, settings, now, act, busy }) {
  const [draft, setDraft] = React.useState('');
  const remaining = focusRemaining(data.focus, now.getTime());
  const submit = async event => {
    event.preventDefault();
    const text = draft.trim();
    if (!text || busy) return;
    if (await act(['productivity', 'add', text])) setDraft('');
  };
  return <Panel name="productivity" label="A little focus" settings={settings}>
    <h3>{data.greeting || (now.getHours() < 12 ? 'Good morning' : now.getHours() < 18 ? 'Good afternoon' : 'Good evening')}</h3>
    <p className="muted">One small thing at a time.</p>
    <ul className="tasks">{(data.tasks || []).map(task => <li key={task.id} className={task.completed ? 'completed' : ''}>
      <label><input type="checkbox" checked={!!task.completed} disabled={busy} onChange={() => act(['productivity', 'toggle', String(task.id)])} /><span className="task-text">{task.text}</span></label>
      <button className="delete-task" aria-label={`Delete ${task.text}`} disabled={busy} onClick={() => act(['productivity', 'remove', String(task.id)])}>×</button>
    </li>)}</ul>
    <form className="task-form" onSubmit={submit}><input aria-label="New checklist item" placeholder="Add a small task…" maxLength={500} value={draft} onChange={event => setDraft(event.target.value)} /><button type="submit" disabled={busy || !draft.trim()} aria-label="Add task">+</button></form>
    <div className="divider" />
    <div className="focus"><div><div className="muted">{remaining === 0 ? 'Session complete' : remaining === null ? '25 minute focus' : 'Focus time'}</div><div className="focus-time" role="timer">{clockDuration(remaining)}</div></div>
      {remaining !== null && remaining > 0 ? <button disabled={busy} onClick={() => act(['productivity', 'stop'])}>Stop</button> : <button className="primary" disabled={busy} onClick={() => act(['productivity', 'focus', '25'])}>Start</button>}
    </div>
  </Panel>;
}

function Dashboard({ output, error }) {
  const [data, setData] = React.useState(() => parsePayload(output));
  const [now, setNow] = React.useState(() => new Date());
  const [busy, setBusy] = React.useState(false);
  const [actionError, setActionError] = React.useState('');
  React.useEffect(() => { setData(parsePayload(output)); }, [output]);
  React.useEffect(() => { const timer = setInterval(() => setNow(new Date()), 1000); return () => clearInterval(timer); }, []);

  async function act(args) {
    const actionCommand = commandFor(runtime, args);
    if (!actionCommand) { setActionError('Install the widgets to connect actions to Aero Blue.'); return false; }
    setBusy(true); setActionError('');
    try {
      const result = await run(actionCommand);
      const response = parsePayload(result);
      if (response.error) throw new Error(response.error);
      setData(parsePayload(await run(pollCommand)));
      return true;
    } catch (failure) {
      setActionError(typeof failure === 'string' ? failure : failure.message || 'The action could not be completed.');
      return false;
    } finally { setBusy(false); }
  }

  if (error || data.error) return <aside className="notice error" role="status">{data.error || 'Device data could not be loaded. Check Aero Blue diagnostics.'}</aside>;
  const settings = data.settings || {};
  if (!settings.enabled) return null;
  const appearance = data.appearance || {};
  const classes = [settings.animations && !appearance.reduceMotion ? 'animated' : '', appearance.reduceTransparency ? 'opaque' : ''].join(' ');
  return <div className={classes}>
    <Clock now={now} settings={settings} />
    <Weather data={data.weather} settings={settings} />
    <System data={data.system} settings={settings} />
    <Music data={data.music} settings={settings} act={act} busy={busy} />
    <Calendar data={data.calendar} settings={settings} now={now} />
    <Productivity data={data.productivity} settings={settings} now={now} act={act} busy={busy} />
    {actionError ? <aside className="notice error" role="alert">{actionError}<br /><button className="small" onClick={() => setActionError('')}>Dismiss</button></aside> : null}
  </div>;
}

export const render = props => <Dashboard {...props} />;
