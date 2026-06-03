<script>
  import { pack, generateSvgString } from './packer.js';
  import { locale, t } from './i18n.js';

  let outerW = 30;
  let outerH = 20;
  let innerW = 7;
  let innerH = 4;

  const MARGIN = 1.0;
  const SW = 0.05;
  const SW_THIN = 0.03;
  const COLOR_BORDER = '#000000';
  const COLOR_BAND1 = '#0066CC';
  const COLOR_BAND2 = '#CC0000';
  const COLOR_SPLIT = '#999999';
  const COLOR_DIM = '#666666';
  const FONT_PIECE = 0.5;
  const FONT_DIM = 0.45;

  const strategyKeys = {
    uniform_a: 'strategyUniformA',
    uniform_b: 'strategyUniformB',
    h_split: 'strategyHSplit',
    v_split: 'strategyVSplit',
  };

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
      <h1>{$t('appTitle')}</h1>
      <div class="lang-toggle">
        <button class:active={$locale === 'en'} on:click={() => locale.set('en')}>EN</button>
        <button class:active={$locale === 'pt'} on:click={() => locale.set('pt')}>PT</button>
      </div>
    </div>
    <p>{$t('appSubtitle')}</p>
  </header>

  <section class="inputs">
    <div class="input-group">
      <label for="outer-w">{$t('labelSheet')}</label>
      <div class="dims">
        <input id="outer-w" type="number" min="0.1" step="0.5" bind:value={outerW} aria-label={$t('ariaSheetWidth')} />
        <span class="sep">×</span>
        <input type="number" min="0.1" step="0.5" bind:value={outerH} aria-label={$t('ariaSheetHeight')} />
        <span class="unit">cm</span>
      </div>
    </div>
    <div class="input-group">
      <label for="inner-w">{$t('labelPiece')}</label>
      <div class="dims">
        <input id="inner-w" type="number" min="0.1" step="0.5" bind:value={innerW} aria-label={$t('ariaPieceWidth')} />
        <span class="sep">×</span>
        <input type="number" min="0.1" step="0.5" bind:value={innerH} aria-label={$t('ariaPieceHeight')} />
        <span class="unit">cm</span>
      </div>
    </div>
  </section>

  {#if valid && result}
    {#if result.count === 0}
      <p class="no-fit">{$t('noFit')}</p>
    {:else}
      <div class="preview-wrap">
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
          <line
            x1={MARGIN} y1={MARGIN + outerH + 0.55}
            x2={MARGIN + outerW} y2={MARGIN + outerH + 0.55}
            stroke={COLOR_DIM} stroke-width={SW_THIN}
          />
          <line
            x1={MARGIN} y1={MARGIN + outerH + 0.35}
            x2={MARGIN} y2={MARGIN + outerH + 0.75}
            stroke={COLOR_DIM} stroke-width={SW_THIN}
          />
          <line
            x1={MARGIN + outerW} y1={MARGIN + outerH + 0.35}
            x2={MARGIN + outerW} y2={MARGIN + outerH + 0.75}
            stroke={COLOR_DIM} stroke-width={SW_THIN}
          />
          <text
            x={MARGIN + outerW / 2} y={MARGIN + outerH + 0.9}
            text-anchor="middle" font-family="sans-serif"
            font-size={FONT_DIM} fill={COLOR_DIM}
          >{fmt(+outerW)} cm</text>

          <!-- height dimension -->
          <line
            x1={MARGIN + outerW + 0.55} y1={MARGIN}
            x2={MARGIN + outerW + 0.55} y2={MARGIN + outerH}
            stroke={COLOR_DIM} stroke-width={SW_THIN}
          />
          <line
            x1={MARGIN + outerW + 0.35} y1={MARGIN}
            x2={MARGIN + outerW + 0.75} y2={MARGIN}
            stroke={COLOR_DIM} stroke-width={SW_THIN}
          />
          <line
            x1={MARGIN + outerW + 0.35} y1={MARGIN + outerH}
            x2={MARGIN + outerW + 0.75} y2={MARGIN + outerH}
            stroke={COLOR_DIM} stroke-width={SW_THIN}
          />
          <text
            x={MARGIN + outerW + 0.9} y={MARGIN + outerH / 2}
            text-anchor="middle" dominant-baseline="middle"
            font-family="sans-serif" font-size={FONT_DIM} fill={COLOR_DIM}
            transform="rotate(90,{MARGIN + outerW + 0.9},{MARGIN + outerH / 2})"
          >{fmt(+outerH)} cm</text>
        </svg>
      </div>

      <section class="stats">
        <div class="stat">
          <span class="stat-value">{result.count}</span>
          <span class="stat-label">{$t('statPieces')}</span>
        </div>
        <div class="stat">
          <span class="stat-value">{fillPercent}%</span>
          <span class="stat-label">{$t('statFill')}</span>
        </div>
        <div class="stat">
          <span class="stat-value">{wasteArea} cm²</span>
          <span class="stat-label">{$t('statWaste')}</span>
        </div>
        <div class="stat layout">
          <span class="stat-label">{$t('statLayout')}</span>
          <span class="stat-value">{strategyKeys[result.strategy] ? $t(strategyKeys[result.strategy]) : '—'}</span>
        </div>
      </section>

      <div class="actions">
        <button class="download" on:click={downloadSvg}>
          {$t('downloadBtn')}
        </button>
      </div>
    {/if}
  {/if}
</main>

<style>
  :global(*, *::before, *::after) { box-sizing: border-box; }

  :global(body) {
    margin: 0;
    background: #f5f5f5;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    color: #111;
  }

  main {
    max-width: 800px;
    margin: 0 auto;
    padding: 2rem 1.5rem;
  }

  header { margin-bottom: 2rem; }

  .title-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.25rem;
  }

  h1 {
    font-size: 1.75rem;
    font-weight: 700;
    margin: 0;
  }

  header p {
    margin: 0;
    color: #666;
    font-size: 0.9rem;
  }

  .lang-toggle {
    display: flex;
    gap: 0.25rem;
  }

  .lang-toggle button {
    background: none;
    border: 1px solid #d0d0d0;
    border-radius: 4px;
    padding: 0.25rem 0.55rem;
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.05em;
    color: #888;
    font-family: inherit;
    cursor: pointer;
    transition: background 0.12s, color 0.12s, border-color 0.12s;
  }

  .lang-toggle button.active {
    background: #0066CC;
    border-color: #0066CC;
    color: white;
  }

  .inputs {
    display: flex;
    gap: 1rem;
    margin-bottom: 2rem;
    flex-wrap: wrap;
  }

  .input-group {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    background: white;
    border: 1px solid #e0e0e0;
    border-radius: 8px;
    padding: 0.6rem 1rem;
  }

  .input-group label {
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: #888;
    min-width: 2.5rem;
  }

  .dims {
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }

  input[type="number"] {
    width: 5rem;
    padding: 0.3rem 0.5rem;
    border: 1px solid #d0d0d0;
    border-radius: 4px;
    font-size: 1rem;
    font-family: inherit;
    text-align: center;
  }

  input[type="number"]:focus {
    outline: 2px solid #0066CC;
    border-color: transparent;
  }

  .sep { color: #bbb; }

  .unit {
    color: #888;
    font-size: 0.85rem;
  }

  .preview-wrap {
    background: white;
    border: 1px solid #e0e0e0;
    border-radius: 8px;
    padding: 1rem;
    margin-bottom: 1.5rem;
  }

  .preview {
    width: 100%;
    height: auto;
    display: block;
  }

  .stats {
    display: flex;
    gap: 0.75rem;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
  }

  .stat {
    background: white;
    border: 1px solid #e0e0e0;
    border-radius: 8px;
    padding: 0.6rem 1rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    min-width: 5rem;
  }

  .stat.layout {
    flex-direction: row;
    gap: 0.5rem;
    align-items: center;
    flex: 1;
  }

  .stat-value {
    font-size: 1.2rem;
    font-weight: 600;
    line-height: 1.2;
  }

  .stat-label {
    font-size: 0.7rem;
    color: #999;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .stat.layout .stat-value {
    font-size: 0.875rem;
    font-weight: 400;
  }

  .actions { display: flex; gap: 1rem; }

  .download {
    background: #0066CC;
    color: white;
    border: none;
    border-radius: 6px;
    padding: 0.65rem 1.25rem;
    font-size: 0.95rem;
    font-family: inherit;
    cursor: pointer;
    transition: background 0.15s;
  }

  .download:hover { background: #0055aa; }

  .no-fit {
    color: #c00;
    background: #fff5f5;
    border: 1px solid #fcc;
    border-radius: 8px;
    padding: 1rem;
  }
</style>
