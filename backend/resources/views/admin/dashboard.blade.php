@extends('admin.layout')

@section('title', 'Dashboard')

@section('content')
<div class="stats">
    <div class="stat">
        <div class="num">{{ $ordersToday }}</div>
        <div class="lbl">Orders today</div>
    </div>
    <div class="stat">
        <div class="num">{{ $onlineRiders }}</div>
        <div class="lbl">Riders online now</div>
    </div>
    <div class="stat">
        <div class="num">₹{{ number_format($platformEarningsToday / 100, 2) }}</div>
        <div class="lbl">Platform earnings today</div>
    </div>
    <div class="stat">
        <div class="num">{{ $pendingApprovals }}</div>
        <div class="lbl">Riders awaiting approval</div>
    </div>
    <div class="stat">
        <div class="num">{{ $pendingPayouts }}</div>
        <div class="lbl">Pending payouts</div>
    </div>
</div>

<div class="card">
    <h3 style="margin-bottom: 12px;">Recent orders</h3>
    <table>
        <thead>
        <tr><th>ID</th><th>Status</th><th>Customer</th><th>Rider</th><th>Fare</th><th>Created</th></tr>
        </thead>
        <tbody>
        @forelse ($recentOrders as $order)
            <tr>
                <td><a href="{{ route('admin.orders.show', $order) }}">#{{ $order->id }}</a></td>
                <td><span class="pill {{ $order->status === 'delivered' ? 'green' : ($order->status === 'cancelled' ? 'red' : ($order->status === 'requested' ? 'amber' : 'blue')) }}">{{ $order->status }}</span></td>
                <td>{{ $order->customer->name ?? '—' }}</td>
                <td>{{ $order->rider->name ?? '—' }}</td>
                <td>₹{{ number_format($order->fare_paise / 100, 2) }}</td>
                <td>{{ $order->created_at->diffForHumans() }}</td>
            </tr>
        @empty
            <tr><td colspan="6" style="color: var(--muted);">No orders yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
