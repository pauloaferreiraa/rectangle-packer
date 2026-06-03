<script>
  import { fade } from 'svelte/transition';
  import { pack, generateSvgString } from './packer.js';
  import { locale, t } from './i18n.js';

  let outerW = 30;
  let outerH = 20;
  let innerW = 7;
  let innerH = 4;

  const MARGIN = 1.5;
  const SW = 0.05;
  const SW_THIN = 0.03;
  const COLOR_BORDER = '#1a1210';
  const COLOR_BAND1 = '#1d4ed8';
  const COLOR_BAND2 = '#b45309';
  const COLOR_SPLIT = '#94a3b8';
  const COLOR_DIM = '#94a3b8';
  const FONT_PIECE = 0.5;
  const FONT_DIM = 0.42;

  const strategyKeys = {
    uniform_a: 'strategyUniformA',
    uniform_b: 'strategyUniformB',
    h_split: 'strategyHSplit',
    v_split: 'strategyVSplit',
  };

  $: if (typeof document !== 'undefined') document.documentElement.lang = $locale;

  $: valid = +outerW > 0 && +outerH > 0 && +innerW > 0 && +innerH > 0;
  $: result = valid ? pack(+outerW, +outerH, +innerW, +innerH) : null;

  $: docW = +outerW + 2 * MARGIN;
  $: docH = +outerH + 2 * MARGIN;

  $: fillPercent = result?.count > 0
    ? ((result.count * innerW * innerH * 100) / (outerW * outerH)).toFixed(1)
    : '0.0';

  $: wasteArea = result?.count > 0
    ? (outerW * outerH - result.count * innerW * innerH).toFixed(2)
    : (+outerW * +outerH).toFixed(2);

  function fmt(val) {
    return val % 1 === 0 ? String(Math.round(val)) : parseFloat(val.toFixed(4)).toString();
  }

  function pieceColor(band) {
    return band === 2 ? COLOR_BAND2 : COLOR_BAND1;
  }

  function downloadSvg() {
    if (!result || result.count === 0) return;
    const svg = generateSvgString(+outerW, +outerH, result);
    const blob = new Blob([svg], { type: 'image/svg+xml' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `layout-${outerW}x${outerH}-piece-${innerW}x${innerH}.svg`;
    a.click();
    URL.revokeObjectURL(url);
  }
</script>

<svelte:head>
  <title>{$t('appTitle')}</title>
</svelte:head>

<main>
  <header>
    <div class="title-row">
      <div class="brand">
        <svg class="brand-mark" width="30" height="21" viewBox="0 0 30 21" fill="none" aria-hidden="true">
          <rect x="0.75" y="0.75" width="28.5" height="19.5" stroke="currentColor" stroke-width="1.5"/>
          <rect x="0.75" y="0.75" width="13" height="9.5" stroke="currentColor" stroke-width="0.75" opacity="0.45"/>
          <rect x="13.75" y="0.75" width="15.5" height="9.5" stroke="currentColor" stroke-width="0.75" opacity="0.45"/>
          <rect x="0.75" y="10.25" width="28.5" height="10" stroke="currentColor" stroke-width="0.75" opacity="0.45"/>
        </svg>
        <h1>{$t('appTitle')}</h1>
      </div>
      <nav class="lang-nav" aria-label="Language">
        <button class:active={$locale === 'en'} on:click={() => locale.set('en')}>EN</button>
        <span class="lang-dot" aria-hidden="true">·</span>
        <button class:active={$locale === 'pt'} on:click={() => locale.set('pt')}>PT</button>
      </nav>
    </div>
    {#key $locale}
      <p class="subtitle" in:fade={{ duration: 160 }}>{$t('appSubtitle')}</p>
    {/key}
  </header>

  <section class="inputs">
    <div class="input-group">
      <label for="outer-w">{$t('labelSheet')}</label>
      <div class="dims">
        <input id="outer-w" type="number" min="0.1" step="0.5" bind:value={outerW} aria-label={$t('ariaSheetWidth')} />
        <span class="times">×</span>
        <input type="number" min="0.1" step="0.5" bind:value={outerH} aria-label={$t('ariaSheetHeight')} />
        <span class="unit">cm</span>
      </div>
    </div>
    <div class="input-group">
      <label for="inner-w">{$t('labelPiece')}</label>
      <div class="dims">
        <input id="inner-w" type="number" min="0.1" step="0.5" bind:value={innerW} aria-label={$t('ariaPieceWidth')} />
        <span class="times">×</span>
        <input type="number" min="0.1" step="0.5" bind:value={innerH} aria-label={$t('ariaPieceHeight')} />
        <span class="unit">cm</span>
      </div>
    </div>
  </section>

  {#if valid && result}
    {#if result.count === 0}
      <p class="no-fit" in:fade={{ duration: 160 }}>{$t('noFit')}</p>
    {:else}
      <div class="preview-wrap" in:fade={{ duration: 200 }}>
        <svg
          viewBox="0 0 {docW} {docH}"
          xmlns="http://www.w3.org/2000/svg"
          class="preview"
        >
          <rect
            x={MARGIN} y={MARGIN}
            width={outerW} height={outerH}
            fill="none" stroke={COLOR_BORDER} stroke-width={SW}
          />

          {#each result.pieces as piece}
            {@const color = pieceColor(piece.band)}
            {@const px = MARGIN + piece.x}
            {@const py = MARGIN + piece.y}
            <rect
              x={px} y={py}
              width={piece.pieceWidth} height={piece.pieceHeight}
              fill="none" stroke={color} stroke-width={SW}
            />
            {#if piece.pieceWidth >= 1.5 && piece.pieceHeight >= 1.0}
              <text
                x={px + piece.pieceWidth / 2}
                y={py + piece.pieceHeight / 2}
                text-anchor="middle"
                dominant-baseline="middle"
                font-family="sans-serif"
                font-size={FONT_PIECE}
                fill={color}
              >{fmt(piece.pieceWidth)}×{fmt(piece.pieceHeight)}</text>
            {/if}
          {/each}

          {#if result.splitAxis === 'h' && result.splitAt !== null}
            <line
              x1={MARGIN} y1={MARGIN + result.splitAt}
              x2={MARGIN + outerW} y2={MARGIN + result.splitAt}
              stroke={COLOR_SPLIT} stroke-width={SW_THIN}
              stroke-dasharray="0.2,0.15"
            />
          {:else if result.splitAxis === 'v' && result.splitAt !== null}
            <line
              x1={MARGIN + result.splitAt} y1={MARGIN}
              x2={MARGIN + result.splitAt} y2={MARGIN + outerH}
              stroke={COLOR_SPLIT} stroke-width={SW_THIN}
              stroke-dasharray="0.2,0.15"
            />
          {/if}

          <!-- width dimension -->
          <line x1={MARGIN} y1={MARGIN + outerH + 0.55} x2={MARGIN + outerW} y2={MARGIN + outerH + 0.55} stroke={COLOR_DIM} stroke-width={SW_THIN}/>
          <line x1={MARGIN} y1={MARGIN + outerH + 0.35} x2={MARGIN} y2={MARGIN + outerH + 0.75} stroke={COLOR_DIM} stroke-width={SW_THIN}/>
          <line x1={MARGIN + outerW} y1={MARGIN + outerH + 0.35} x2={MARGIN + outerW} y2={MARGIN + outerH + 0.75} stroke={COLOR_DIM} stroke-width={SW_THIN}/>
          <text x={MARGIN + outerW / 2} y={MARGIN + outerH + 0.9} text-anchor="middle" font-family="sans-serif" font-size={FONT_DIM} fill={COLOR_DIM}>{fmt(+outerW)} cm</text>

          <!-- height dimension -->
          <line x1={MARGIN + outerW + 0.55} y1={MARGIN} x2={MARGIN + outerW + 0.55} y2={MARGIN + outerH} stroke={COLOR_DIM} stroke-width={SW_THIN}/>
          <line x1={MARGIN + outerW + 0.35} y1={MARGIN} x2={MARGIN + outerW + 0.75} y2={MARGIN} stroke={COLOR_DIM} stroke-width={SW_THIN}/>
          <line x1={MARGIN + outerW + 0.35} y1={MARGIN + outerH} x2={MARGIN + outerW + 0.75} y2={MARGIN + outerH} stroke={COLOR_DIM} stroke-width={SW_THIN}/>
          <text x={MARGIN + outerW + 0.9} y={MARGIN + outerH / 2} text-anchor="middle" dominant-baseline="middle" font-family="sans-serif" font-size={FONT_DIM} fill={COLOR_DIM} transform="rotate(90,{MARGIN + outerW + 0.9},{MARGIN + outerH / 2})">{fmt(+outerH)} cm</text>
        </svg>
      </div>

      <div class="stats-strip">
        <div class="stat-cell">
          <span class="stat-num">{result.count}</span>
          <span class="stat-lbl">{$t('statPieces')}</span>
        </div>
        <div class="stat-rule" />
        <div class="stat-cell">
          <span class="stat-num">{fillPercent}%</span>
          <span class="stat-lbl">{$t('statFill')}</span>
        </div>
        <div class="stat-rule" />
        <div class="stat-cell">
          <span class="stat-num">{wasteArea} cm²</span>
          <span class="stat-lbl">{$t('statWaste')}</span>
        </div>
        <div class="stat-rule" />
        <div class="stat-cell stat-cell--wide">
          <span class="stat-lbl">{$t('statLayout')}</span>
          <span class="stat-strategy">{strategyKeys[result.strategy] ? $t(strategyKeys[result.strategy]) : '—'}</span>
        </div>
      </div>

      <div class="actions">
        <button class="download" on:click={downloadSvg}>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M7 1.5v7M3.5 6l3.5 3.5L10.5 6M1.5 12.5h11"/>
          </svg>
          {$t('downloadBtn')}
        </button>
      </div>
    {/if}
  {/if}
</main>

<style>
  :global(*, *::before, *::after) {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }

  :global(:root) {
    --bg: #f8f5f0;
    --surface: #ffffff;
    --ink: #18120e;
    --ink-2: #786e66;
    --ink-3: #b0a89e;
    --accent: #1d4ed8;
    --border: #e4ddd4;
    --border-2: #ede9e3;
    --font-display: 'Playfair Display', Georgia, serif;
    --font-body: 'DM Sans', system-ui, sans-serif;
    --font-mono: 'DM Mono', 'Courier New', monospace;
  }

  :global(body) {
    background-color: var(--bg);
    background-image: radial-gradient(circle, #d6d0c6 1.5px, transparent 1.5px);
    background-size: 22px 22px;
    font-family: var(--font-body);
    color: var(--ink);
    -webkit-font-smoothing: antialiased;
    min-height: 100vh;
  }

  main {
    max-width: 860px;
    margin: 0 auto;
    padding: 3.5rem 2rem 5rem;
  }

  /* ── Header ── */
  header {
    margin-bottom: 2.75rem;
  }

  .title-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.6rem;
  }

  .brand {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .brand-mark {
    color: var(--ink);
    opacity: 0.75;
    flex-shrink: 0;
  }

  h1 {
    font-family: var(--font-display);
    font-size: 2.25rem;
    font-weight: 900;
    letter-spacing: -0.025em;
    line-height: 1;
    color: var(--ink);
  }

  .subtitle {
    font-size: 0.9375rem;
    font-weight: 300;
    color: var(--ink-2);
    letter-spacing: 0.01em;
    padding-left: calc(30px + 0.75rem);
  }

  /* ── Language nav ── */
  .lang-nav {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    font-family: var(--font-body);
    font-size: 0.75rem;
    font-weight: 500;
    letter-spacing: 0.08em;
  }

  .lang-nav button {
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    font-family: inherit;
    font-size: inherit;
    font-weight: inherit;
    letter-spacing: inherit;
    color: var(--ink-3);
    transition: color 0.12s;
  }

  .lang-nav button.active {
    color: var(--ink);
    font-weight: 600;
  }

  .lang-nav button:hover:not(.active) {
    color: var(--ink-2);
  }

  .lang-dot {
    color: var(--ink-3);
    user-select: none;
    font-size: 0.9rem;
  }

  /* ── Inputs ── */
  .inputs {
    display: flex;
    gap: 1rem;
    margin-bottom: 2rem;
    flex-wrap: wrap;
  }

  .input-group {
    display: flex;
    align-items: center;
    gap: 1rem;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 0.8rem 1.25rem;
    box-shadow: 0 1px 3px rgba(24,18,14,0.05);
  }

  .input-group label {
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--ink-3);
    min-width: 2.75rem;
  }

  .dims {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  input[type="number"] {
    width: 4.5rem;
    padding: 0.2rem 0;
    background: transparent;
    border: none;
    border-bottom: 1.5px solid var(--border);
    border-radius: 0;
    font-family: var(--font-mono);
    font-size: 1.125rem;
    font-weight: 500;
    color: var(--ink);
    text-align: center;
    transition: border-color 0.15s;
    -moz-appearance: textfield;
  }

  input[type="number"]::-webkit-inner-spin-button,
  input[type="number"]::-webkit-outer-spin-button {
    opacity: 0;
  }

  input[type="number"]:focus {
    outline: none;
    border-bottom-color: var(--accent);
  }

  .times {
    color: var(--ink-3);
    font-size: 0.875rem;
    font-weight: 300;
  }

  .unit {
    font-size: 0.8125rem;
    color: var(--ink-2);
    font-weight: 400;
  }

  /* ── Preview ── */
  .preview-wrap {
    background: var(--surface);
    border: 1px solid var(--border-2);
    border-radius: 4px;
    padding: 1.75rem;
    margin-bottom: 1.25rem;
    box-shadow:
      0 1px 2px rgba(24,18,14,0.04),
      0 6px 18px rgba(24,18,14,0.07),
      0 20px 48px rgba(24,18,14,0.05);
  }

  .preview {
    display: block;
    width: 100%;
    height: auto;
  }

  /* ── Stats strip ── */
  .stats-strip {
    display: flex;
    align-items: stretch;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    margin-bottom: 1.5rem;
    overflow: hidden;
    box-shadow: 0 1px 3px rgba(24,18,14,0.05);
  }

  .stat-cell {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 1rem 0.75rem;
    gap: 0.25rem;
    min-width: 0;
  }

  .stat-cell--wide {
    flex: 1.8;
    align-items: flex-start;
    padding-left: 1.25rem;
    padding-right: 1.25rem;
  }

  .stat-rule {
    width: 1px;
    background: var(--border-2);
    flex-shrink: 0;
    align-self: stretch;
  }

  .stat-num {
    font-family: var(--font-mono);
    font-size: 1.3rem;
    font-weight: 500;
    color: var(--ink);
    letter-spacing: -0.02em;
    line-height: 1.1;
    white-space: nowrap;
  }

  .stat-lbl {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--ink-3);
  }

  .stat-strategy {
    font-size: 0.8125rem;
    font-weight: 400;
    color: var(--ink-2);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 100%;
  }

  /* ── Actions ── */
  .actions {
    display: flex;
  }

  .download {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    background: var(--ink);
    color: #f8f5f0;
    border: none;
    border-radius: 7px;
    padding: 0.75rem 1.5rem;
    font-family: var(--font-body);
    font-size: 0.875rem;
    font-weight: 500;
    letter-spacing: 0.01em;
    cursor: pointer;
    transition: background 0.15s, transform 0.1s;
  }

  .download:hover {
    background: #2e231c;
    transform: translateY(-1px);
  }

  .download:active {
    transform: translateY(0);
  }

  /* ── No-fit message ── */
  .no-fit {
    background: #fefaf4;
    border: 1px solid #e8d5a8;
    border-radius: 8px;
    padding: 1rem 1.25rem;
    font-size: 0.9rem;
    color: #92400e;
  }

  /* ── Mobile ── */
  @media (max-width: 520px) {
    main { padding: 2rem 1.25rem 3rem; }
    h1 { font-size: 1.75rem; }
    .subtitle { padding-left: 0; }
    .brand-mark { display: none; }

    .stats-strip {
      flex-wrap: wrap;
    }
    .stat-cell {
      flex: 1 1 30%;
    }
    .stat-cell--wide {
      flex: 1 1 100%;
      border-top: 1px solid var(--border-2);
      align-items: center;
    }
    .stat-rule:last-of-type {
      display: none;
    }
  }
</style>
