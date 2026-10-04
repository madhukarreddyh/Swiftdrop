@extends('admin.layout')

@section('title', 'Rider #' . $rider->id)

@section('content')
<div class="card">
    <h3 style="margin-bottom: 16px;">{{ $rider->name }} — +91 {{ $rider->phone }}</h3>
    <dl class="kv">
        <dt>Status</dt>
        <dd>
            @if (($rider->riderProfile->verification_status ?? 'pending') === 'approved')
                <span class="pill green">approved</span>
            @elseif (($rider->riderProfile->verification_status ?? 'pending') === 'rejected')
                <span class="pill red">rejected</span>
            @else
                <span class="pill amber">pending</span>
            @endif
        </dd>
        <dt>Online</dt><dd>{{ ($rider->riderProfile->is_online ?? false) ? 'Yes' : 'No' }}</dd>
        <dt>Total trips</dt><dd>{{ $rider->riderProfile->total_trips ?? 0 }}</dd>
        <dt>Rating</dt><dd>{{ $rider->riderProfile->rating ?? '—' }}</dd>
        <dt>Aadhaar</dt><dd>{{ $rider->riderProfile->aadhaar ?? '—' }}</dd>
        <dt>Licence no.</dt><dd>{{ $rider->riderProfile->licence_no ?? '—' }}</dd>
        <dt>Bike RC</dt><dd>{{ $rider->riderProfile->bike_rc ?? '—' }}</dd>
        <dt>Bike number</dt><dd>{{ $rider->riderProfile->bike_number ?? '—' }}</dd>
        <dt>Vehicle type</dt><dd>{{ ucfirst($rider->riderProfile->vehicle_type ?? 'bike') }}</dd>
        <dt>Bank account</dt><dd>{{ $rider->riderProfile->bank_account ?? '—' }}</dd>
        <dt>Joined</dt><dd>{{ $rider->created_at->format('d M Y, h:i A') }}</dd>
    </dl>

    <div style="margin-top: 20px; display: flex; gap: 10px;">
        <form class="inline-form" method="POST" action="{{ route('admin.riders.verify', $rider) }}">
            @csrf
            <input type="hidden" name="approved" value="1">
            <button class="btn" type="submit">Approve</button>
        </form>
        <form class="inline-form" method="POST" action="{{ route('admin.riders.verify', $rider) }}">
            @csrf
            <input type="hidden" name="approved" value="0">
            <button class="btn danger" type="submit">Reject</button>
        </form>
        <a class="btn ghost" href="{{ route('admin.riders') }}">Back to list</a>
    </div>
</div>

<div class="card">
    <h3 style="margin-bottom: 12px;">Recent orders</h3>
    <table>
        <thead>
        <tr><th>ID</th><th>Status</th><th>Fare</th><th>Rider earning</th><th>Created</th></tr>
        </thead>
        <tbody>
        @forelse ($orders as $order)
            <tr>
                <td><a href="{{ route('admin.orders.show', $order) }}">#{{ $order->id }}</a></td>
                <td>{{ $order->status }}</td>
                <td>₹{{ number_format($order->fare_paise / 100, 2) }}</td>
                <td>₹{{ number_format(($order->rider_earning_paise ?? 0) / 100, 2) }}</td>
                <td>{{ $order->created_at->diffForHumans() }}</td>
            </tr>
        @empty
            <tr><td colspan="5" style="color: var(--muted);">No orders yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
