import { useEffect, useReducer, useState } from 'react';
import type { WorldStatus } from '@worldpulse/shared';
import { readWorldStatus, statusPath, type StatusResult } from './world-status';

type ViewState = StatusResult | { kind: 'loading' };

const simulationLabel: Record<WorldStatus['simulationStatus'], string> = {
  not_started: 'Not started',
};

const connection = {
  ready: 'Connected',
  loading: 'Checking connection',
  offline: 'Disconnected',
  unreachable: 'Disconnected',
  'http-error': 'Connection error',
  'invalid-response': 'Invalid response',
} satisfies Record<ViewState['kind'], string>;

function statusMessage(state: Exclude<ViewState, { kind: 'ready' }>) {
  switch (state.kind) {
    case 'loading':
      return ['Loading world status', 'Waiting for a response from the world server.'];
    case 'offline':
      return ['Your browser is offline', 'Reconnect to the network to check world status.'];
    case 'unreachable':
      return ['World server unreachable', 'Check that the world server is running, then refresh status.'];
    case 'http-error':
      return ['World status unavailable', `The world server returned HTTP ${state.status}. Refresh status to check again.`];
    case 'invalid-response':
      return ['Unexpected status response', 'The response did not match the world status format.'];
  }
}

export function App() {
  const [state, setState] = useState<ViewState>(
    () => ({ kind: navigator.onLine ? 'loading' : 'offline' }),
  );
  const [attempt, refresh] = useReducer((count: number) => count + 1, 0);

  useEffect(() => {
    const request = new AbortController();
    function markOffline() {
      request.abort();
      setState({ kind: 'offline' });
    }

    window.addEventListener('online', refresh);
    window.addEventListener('offline', markOffline);

    if (navigator.onLine) {
      setState({ kind: 'loading' });
      const signal = AbortSignal.any([request.signal, AbortSignal.timeout(8000)]);
      void readWorldStatus(signal).then((result) => {
        if (!request.signal.aborted) setState(result);
      });
    } else {
      markOffline();
    }

    return () => {
      request.abort();
      window.removeEventListener('online', refresh);
      window.removeEventListener('offline', markOffline);
    };
  }, [attempt]);

  const busy = state.kind === 'loading';
  const world = state.kind === 'ready' ? state.world : null;
  const message = state.kind !== 'ready' ? statusMessage(state) : null;

  return (
    <div className="shell">
      <header className="masthead">
        <span className="wordmark">WorldPulse</span>
        <span className="edition">v0.1A</span>
      </header>

      <main>
        <h1>World status</h1>
        <section className="readout" aria-label="World status readout" data-state={state.kind}>
          <div className="readout-header">
            <p className="connection" role="status">
              <span className="signal" aria-hidden="true" />
              {connection[state.kind]}
            </p>
            <button
              type="button"
              disabled={busy || state.kind === 'offline'}
              onClick={() => refresh()}
            >
              {busy ? 'Checking status' : 'Refresh status'}
            </button>
          </div>

          <div className="readout-body" aria-busy={busy}>
            {world ? (
              <>
                <div className="primary">
                  <div className="world">
                    <p className="label">World</p>
                    <h2>{world.worldName}</h2>
                  </div>
                  <dl className="simulation">
                    <dt className="label">Simulation</dt>
                    <dd>{simulationLabel[world.simulationStatus]}</dd>
                  </dl>
                </div>
                <dl className="details">
                  <div>
                    <dt className="label">Citizens</dt>
                    <dd>{world.citizens.toLocaleString()}</dd>
                  </div>
                  <div>
                    <dt className="label">World time</dt>
                    <dd>{world.worldTime ? <time dateTime={world.worldTime}>{world.worldTime}</time> : 'Not set'}</dd>
                  </div>
                  <div>
                    <dt className="label">World ID</dt>
                    <dd><code>{world.worldId}</code></dd>
                  </div>
                </dl>
              </>
            ) : message && (
              <div className="empty">
                <h2>{message[0]}</h2>
                <p>{message[1]}</p>
              </div>
            )}
          </div>
        </section>
      </main>

      <footer className="provenance">
        <span>Read-only snapshot</span>
        <code>GET {statusPath}</code>
      </footer>
    </div>
  );
}
