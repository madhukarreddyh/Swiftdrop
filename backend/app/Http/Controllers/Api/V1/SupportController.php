<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\SupportTicket;
use Illuminate\Http\Request;

class SupportController extends Controller
{
    /**
     * POST /api/v1/support/tickets  {subject, order_id?, message}
     */
    public function store(Request $request)
    {
        $data = $request->validate([
            'subject' => ['required', 'string', 'max:255'],
            'order_id' => ['nullable', 'exists:orders,id'],
            'message' => ['required', 'string', 'max:2000'],
        ]);

        $ticket = SupportTicket::create([
            'user_id' => $request->user()->id,
            'order_id' => $data['order_id'] ?? null,
            'subject' => $data['subject'],
            'status' => 'open',
            'messages' => [
                [
                    'from' => $request->user()->role,
                    'body' => $data['message'],
                    'at' => now()->toIso8601String(),
                ],
            ],
        ]);

        return response()->json($ticket, 201);
    }

    /**
     * GET /api/v1/support/tickets
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $query = SupportTicket::with('order:id')->latest();

        if (!$user->isAdmin()) {
            $query->where('user_id', $user->id);
        }

        return response()->json($query->paginate(20));
    }

    /**
     * POST /api/v1/support/tickets/{ticket}/reply  {message}
     */
    public function reply(Request $request, SupportTicket $ticket)
    {
        $user = $request->user();

        if (!$user->isAdmin() && $ticket->user_id !== $user->id) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        $data = $request->validate(['message' => ['required', 'string', 'max:2000']]);

        $messages = $ticket->messages ?? [];
        $messages[] = [
            'from' => $user->isAdmin() ? 'admin' : $user->role,
            'body' => $data['message'],
            'at' => now()->toIso8601String(),
        ];

        $ticket->update([
            'messages' => $messages,
            'status' => $user->isAdmin() ? 'in_progress' : $ticket->status,
        ]);

        return response()->json($ticket->fresh());
    }
}
