@extends('admin.layout')

@section('title', 'Zones')

@section('content')
<div class="card">
    <table>
        <thead>
        <tr><th>Name</th><th>Status</th><th>Boundary points</th><th></th></tr>
        </thead>
        <tbody>
        @forelse ($zones as $zone)
            <tr>
                <td><strong>{{ $zone->name }}</strong></td>
                <td>
                    @if ($zone->is_active)
                        <span class="pill green">active</span>
                    @else
                        <span class="pill gray">inactive</span>
                    @endif
                </td>
                <td>{{ is_array($zone->polygon) ? count($zone->polygon) : 0 }} points</td>
                <td>
                    <form class="inline-form" method="POST" action="{{ route('admin.zones.toggle', $zone) }}">
                        @csrf
                        <button class="btn small {{ $zone->is_active ? 'ghost' : '' }}" type="submit">
                            {{ $zone->is_active ? 'Deactivate' : 'Activate' }}
                        </button>
                    </form>
                </td>
            </tr>
        @empty
            <tr><td colspan="4" style="color: var(--muted);">No zones defined.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
