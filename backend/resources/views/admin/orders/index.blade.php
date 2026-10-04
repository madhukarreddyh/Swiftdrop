@extends('admin.layout')

@section('title', 'Orders')

@section('content')
<div class="filterbar">
    <form method="GET" action="{{ route('admin.orders') }}">
        <select name="status" onchange="this.form.submit()">
            <option value="">All statuses</option>
            @foreach ($statuses as $s)
                <option value="{{ $s }}" {{ $status === $s ? 'selected' : '' }}>{{ $s }}</option>
            @endforeach
        </select>
    </form>
</div>

<div class="card">
    <table>
        <thead>
        <tr><th>ID</th><th>Status</th><th>Customer</th><th>Rider</th><th>Pickup → Drop</th><th>Fare</th><th>Created</th></tr>
        </thead>
        <tbody>
        @forelse ($orders as $order)
            <tr>
                <td><a href="{{ route('admin.orders.show', $order) }}">#{{ $order->id }}</a></td>
                <td>
                    @if ($order->status === 'delivered')
                        <span class="pill green">{{ $order->status }}</span>
                    @elseif ($order->status === 'cancelled')
                        <span class="pill red">{{ $order->status }}</span>
                    @elseif ($order->status === 'requested')
                        <span class="pill amber">{{ $order->status }}</span>
                    @else
                        <span class="pill blue">{{ $order->status }}</span>
                    @endif
                </td>
                <td>{{ $order->customer->name ?? '—' }}<br><small style="color: var(--muted);">{{ $order->customer->phone ?? '' }}</small></td>
                <td>{{ $order->rider->name ?? '—' }}</td>
                <td><small>{{ \Illuminate\Support\Str::limit($order->pickup_address, 30) }} → {{ \Illuminate\Support\Str::limit($order->drop_address, 30) }}</small></td>
                <td>₹{{ number_format($order->fare_paise / 100, 2) }}</td>
                <td>{{ $order->created_at->diffForHumans() }}</td>
            </tr>
        @empty
            <tr><td colspan="7" style="color: var(--muted);">No orders found.</td></tr>
        @endforelse
        </tbody>
    </table>
    <div class="pagination">{{ $orders->links() }}</div>
</div>
@endsection
