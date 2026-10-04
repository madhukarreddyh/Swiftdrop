@extends('admin.layout')

@section('title', 'Fare settings')

@section('content')
<div class="card">
    <p style="color: var(--muted); font-size: 14px; margin-bottom: 20px;">
        Money is stored in paise (100 paise = ₹1). Changes apply instantly — no app update needed.
    </p>
    <form method="POST" action="{{ route('admin.fare.update') }}">
        @csrf
        <div class="field">
            <label for="base_fare_paise">Base fare (paise)</label>
            <input id="base_fare_paise" name="base_fare_paise" type="number" min="0" value="{{ $settings['base_fare_paise'] }}">
            <div class="hint">Covers the first {{ $settings['base_km'] }} km. Currently ₹{{ number_format($settings['base_fare_paise'] / 100, 2) }}.</div>
        </div>
        <div class="field">
            <label for="base_km">Base kilometres</label>
            <input id="base_km" name="base_km" type="number" min="0" value="{{ $settings['base_km'] }}">
        </div>
        <div class="field">
            <label for="per_km_paise">Per extra km (paise)</label>
            <input id="per_km_paise" name="per_km_paise" type="number" min="0" value="{{ $settings['per_km_paise'] }}">
            <div class="hint">Currently ₹{{ number_format($settings['per_km_paise'] / 100, 2) }} per km after the base distance.</div>
        </div>
        <div class="field">
            <label for="night_charge_paise">Night charge (paise)</label>
            <input id="night_charge_paise" name="night_charge_paise" type="number" min="0" value="{{ $settings['night_charge_paise'] }}">
        </div>
        <div class="field">
            <label for="min_fare_paise">Minimum fare (paise)</label>
            <input id="min_fare_paise" name="min_fare_paise" type="number" min="0" value="{{ $settings['min_fare_paise'] }}">
        </div>
        <div class="field">
            <label for="platform_commission_pct">Platform commission (%)</label>
            <input id="platform_commission_pct" name="platform_commission_pct" type="number" min="0" max="100" value="{{ $settings['platform_commission_pct'] }}">
            <div class="hint">Rider keeps {{ 100 - (int) $settings['platform_commission_pct'] }}% of each fare.</div>
        </div>
        <button class="btn" type="submit">Save fare settings</button>
    </form>
</div>
@endsection
