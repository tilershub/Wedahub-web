<script lang="ts">
  let lengthFt: number = 0;
  let lengthIn: number = 0;
  let widthFt: number = 0;
  let widthIn: number = 0;
  let calculated = false;
  let error = '';

  $: lenDecimal = Number(lengthFt) + Number(lengthIn) / 12;
  $: widDecimal = Number(widthFt)  + Number(widthIn)  / 12;
  $: area       = lenDecimal * widDecimal;
  $: skirting   = 2 * (lenDecimal + widDecimal);

  function calculate() {
    error = '';
    if (Number(lengthFt) < 1 || Number(widthFt) < 1) {
      error = 'Please enter at least 1 ft for both Length and Width.';
      calculated = false;
      return;
    }
    calculated = true;
  }

  function reset() {
    lengthFt = 0; lengthIn = 0;
    widthFt  = 0; widthIn  = 0;
    calculated = false;
    error = '';
  }
</script>

<div class="rounded-2xl border border-stone-200 bg-white p-6 shadow-sm">
  <div class="mb-5 flex items-center gap-3">
    <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-orange-100 text-xl">📐</span>
    <div>
      <h2 class="text-lg font-bold text-stone-900">Floor Area Calculator</h2>
      <p class="text-xs text-stone-500">Enter room dimensions to estimate floor area and skirting</p>
    </div>
  </div>

  <!-- Inputs -->
  <div class="space-y-4">
    <!-- Length -->
    <div>
      <label class="mb-1.5 block text-sm font-medium text-stone-700">Length</label>
      <div class="flex items-center gap-2">
        <input
          type="number"
          bind:value={lengthFt}
          min="0"
          placeholder="13"
          class="w-24 rounded-xl border border-stone-200 bg-white px-3 py-2 text-sm text-stone-900 outline-none focus:border-orange-400 focus:ring-2 focus:ring-orange-200"
        />
        <span class="text-sm font-medium text-stone-500">ft</span>
        <input
          type="number"
          bind:value={lengthIn}
          min="0"
          max="11"
          placeholder="6"
          class="w-20 rounded-xl border border-stone-200 bg-white px-3 py-2 text-sm text-stone-900 outline-none focus:border-orange-400 focus:ring-2 focus:ring-orange-200"
        />
        <span class="text-sm font-medium text-stone-500">in</span>
      </div>
    </div>

    <!-- Width -->
    <div>
      <label class="mb-1.5 block text-sm font-medium text-stone-700">Width</label>
      <div class="flex items-center gap-2">
        <input
          type="number"
          bind:value={widthFt}
          min="0"
          placeholder="13"
          class="w-24 rounded-xl border border-stone-200 bg-white px-3 py-2 text-sm text-stone-900 outline-none focus:border-orange-400 focus:ring-2 focus:ring-orange-200"
        />
        <span class="text-sm font-medium text-stone-500">ft</span>
        <input
          type="number"
          bind:value={widthIn}
          min="0"
          max="11"
          placeholder="6"
          class="w-20 rounded-xl border border-stone-200 bg-white px-3 py-2 text-sm text-stone-900 outline-none focus:border-orange-400 focus:ring-2 focus:ring-orange-200"
        />
        <span class="text-sm font-medium text-stone-500">in</span>
      </div>
    </div>
  </div>

  <!-- Error -->
  {#if error}
    <p class="mt-3 text-xs font-medium text-red-600">{error}</p>
  {/if}

  <!-- Actions -->
  <div class="mt-5 flex gap-3">
    <button
      on:click={calculate}
      class="rounded-xl bg-orange-500 px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-orange-600 focus:outline-none focus:ring-2 focus:ring-orange-400"
    >
      Calculate
    </button>
    {#if calculated}
      <button
        on:click={reset}
        class="rounded-xl border border-stone-200 px-5 py-2.5 text-sm font-semibold text-stone-600 transition hover:bg-stone-50"
      >
        Reset
      </button>
    {/if}
  </div>

  <!-- Results -->
  {#if calculated}
    <div class="mt-6 grid gap-4 sm:grid-cols-2">
      <!-- Floor Area -->
      <div class="rounded-xl bg-orange-50 p-4">
        <p class="text-xs font-semibold uppercase tracking-wide text-orange-600">Floor Area</p>
        <p class="mt-1 text-3xl font-bold text-stone-900">{area.toFixed(2)}</p>
        <p class="text-sm font-medium text-stone-600">sq.ft</p>
        <p class="mt-2 text-xs text-stone-500">
          {lenDecimal.toFixed(2)} ft × {widDecimal.toFixed(2)} ft
        </p>
      </div>

      <!-- Skirting Length -->
      <div class="rounded-xl bg-stone-50 p-4">
        <p class="text-xs font-semibold uppercase tracking-wide text-stone-500">Skirting Length</p>
        <p class="mt-1 text-3xl font-bold text-stone-900">{skirting.toFixed(2)}</p>
        <p class="text-sm font-medium text-stone-600">lin.ft</p>
        <p class="mt-2 text-xs text-stone-400">
          Assumes 4 straight walls (full perimeter). Subtract ~3 ft per doorway.
        </p>
      </div>
    </div>
  {/if}
</div>
