@extends('admin.layout')

@section('title', 'Riders')

@section('content')
<div class="filterbar">
    <form method="GET" action="{{ route('admin.riders') }}">
        <select name="status" onchange="this.form.submit()">
            <option value="">All statuses</option>
            @foreach (['pending', 'approved', 'rejected'] as $s)
                <option value="{{ $s }}" {{ $status === $s ? 'selected' : '' }}>{{ ucfirst($s) }}</option>
            @endforeach
        </select>
    </form>
</div>

<div class="card">
    <table>
        <thead>
        <tr><th>Name</th><th>Phone</th><th>Bike</th><th>Verification</th><th>Online</th><th>Trips</th><th></th></tr>
        </thead>
        <tbody>
        @forelse ($riders as $rider)
            <tr>
                <td>{{ $rider->name }}</td>
                <td>{{ $rider->phone }}</td>
                <td>{{ $rider->riderProfile->bike_number ?? '—' }}</td>
                <td>
                    @if (($rider->riderProfile->verification_status ?? 'pending') === 'approved')
                        <span class="pill green">approved</span>
                    @elseif (($rider->riderProfile->verification_status ?? 'pending') === 'rejected')
                        <span class="pill red">rejected</span>
                    @else
                        <span class="pill amber">pending</span>
                    @endif
                </td>
                <td>{{ ($rider->riderProfile->is_online ?? false) ? 'Yes' : 'No' }}</td>
                <td>{{ $rider->riderProfile->total_trips ?? 0 }}</td>
                <td><a class="btn small ghost" href="{{ route('admin.riders.show', $rider) }}">View</a></td>
            </tr>
        @empty
            <tr><td colspan="7" style="color: var(--muted);">No riders found.</td></tr>
        @endforelse
        </tbody>
    </table>
    <div class="pagination">{{ $riders->links() }}</div>
</div>
@endsection
