@extends('admin.layout')

@section('title', 'Order #' . $order->id)

@section('content')
<div class="card">
    <h3 style="margin-bottom: 16px;">Order #{{ $order->id }}
        @if ($order->status === 'delivered')
            <span class="pill green">{{ $order->status }}</span>
        @elseif ($order->status === 'cancelled')
            <span class="pill red">{{ $order->status }}</span>
        @elseif ($order->status === 'requested')
            <span class="pill amber">{{ $order->status }}</span>
        @else
            <span class="pill blue">{{ $order->status }}</span>
        @endif
    </h3>
    <dl class="kv">
        <dt>Customer</dt><dd>{{ $order->customer->name ?? '—' }} (+91 {{ $order->customer->phone ?? '—' }})</dd>
        <dt>Rider</dt><dd>{{ $order->rider->name ?? 'Unassigned' }}{{ $order->rider ? ' (+91 ' . $order->rider->phone . ')' : '' }}</dd>
        <dt>Pickup</dt><dd>{{ $order->pickup_address }} <small style="color: var(--muted);">({{ $order->pickup_lat }}, {{ $order->pickup_lng }})</small></dd>
        <dt>Drop</dt><dd>{{ $order->drop_address }} <small style="color: var(--muted);">({{ $order->drop_lat }}, {{ $order->drop_lng }})</small></dd>
        <dt>Distance</dt><dd>{{ $order->distance_km }} km</dd>
        <dt>Fare</dt><dd>₹{{ number_format($order->fare_paise / 100, 2) }}</dd>
        <dt>Platform fee</dt><dd>₹{{ number_format(($order->platform_fee_paise ?? 0) / 100, 2) }}</dd>
        <dt>Rider earning</dt><dd>₹{{ number_format(($order->rider_earning_paise ?? 0) / 100, 2) }}</dd>
        <dt>Created</dt><dd>{{ $order->created_at->format('d M Y, h:i A') }}</dd>
        <dt>Delivered</dt><dd>{{ $order->delivered_at ? $order->delivered_at->format('d M Y, h:i A') : '—' }}</dd>
    </dl>
    <div style="margin-top: 20px;">
        <a class="btn ghost" href="{{ route('admin.orders') }}">Back to list</a>
    </div>
</div>
@endsection
