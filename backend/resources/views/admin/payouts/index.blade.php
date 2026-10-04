@extends('admin.layout')

@section('title', 'Payouts')

@section('content')
<div class="card">
    <h3 style="margin-bottom: 12px;">Generate payouts</h3>
    <form method="POST" action="{{ route('admin.payouts.generate') }}" style="display: flex; gap: 10px; align-items: flex-end; flex-wrap: wrap;">
        @csrf
        <div class="field" style="margin-bottom: 0;">
            <label for="period_start">Period start</label>
            <input id="period_start" name="period_start" type="date" value="{{ now()->startOfMonth()->toDateString() }}" required>
        </div>
        <div class="field" style="margin-bottom: 0;">
            <label for="period_end">Period end</label>
            <input id="period_end" name="period_end" type="date" value="{{ now()->toDateString() }}" required>
        </div>
        <button class="btn" type="submit">Generate</button>
    </form>
    <p style="color: var(--muted); font-size: 13px; margin-top: 10px;">One payout row per rider with delivered trips in the period. Re-running for the same period updates the rows.</p>
</div>

<div class="filterbar">
    <form method="GET" action="{{ route('admin.payouts') }}">
        <select name="status" onchange="this.form.submit()">
            <option value="">All statuses</option>
            @foreach (['pending', 'paid'] as $s)
                <option value="{{ $s }}" {{ $status === $s ? 'selected' : '' }}>{{ ucfirst($s) }}</option>
            @endforeach
        </select>
    </form>
</div>

<div class="card">
    <table>
        <thead>
        <tr><th>Rider</th><th>Period</th><th>Trips</th><th>Amount</th><th>Status</th><th>Bank ref</th><th></th></tr>
        </thead>
        <tbody>
        @forelse ($payouts as $payout)
            <tr>
                <td>{{ $payout->rider->name ?? '—' }}<br><small style="color: var(--muted);">{{ $payout->rider->phone ?? '' }}</small></td>
                <td><small>{{ $payout->period_start->format('d M Y') }} → {{ $payout->period_end->format('d M Y') }}</small></td>
                <td>{{ $payout->trips }}</td>
                <td>₹{{ number_format($payout->amount_paise / 100, 2) }}</td>
                <td>
                    @if ($payout->status === 'paid')
                        <span class="pill green">paid</span>
                    @else
                        <span class="pill amber">pending</span>
                    @endif
                </td>
                <td>{{ $payout->bank_ref ?? '—' }}</td>
                <td>
                    @if ($payout->status !== 'paid')
                        <form class="inline-form" method="POST" action="{{ route('admin.payouts.mark-paid', $payout) }}" style="display: flex; gap: 6px;">
                            @csrf
                            <input type="text" name="bank_ref" placeholder="Bank ref (optional)" style="padding: 6px 10px; border: 1px solid var(--line); border-radius: 8px; font-size: 12px; width: 140px;">
                            <button class="btn small" type="submit">Mark paid</button>
                        </form>
                    @else
                        <small style="color: var(--muted);">{{ $payout->paid_at ? $payout->paid_at->format('d M Y') : '' }}</small>
                    @endif
                </td>
            </tr>
        @empty
            <tr><td colspan="7" style="color: var(--muted);">No payouts yet. Generate one above.</td></tr>
        @endforelse
        </tbody>
    </table>
    <div class="pagination">{{ $payouts->links() }}</div>
</div>
@endsection
