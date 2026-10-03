<?php

namespace App\Console\Commands;

use App\Services\MatchingService;
use Illuminate\Console\Command;

class ReassignExpiredOrders extends Command
{
    protected $signature = 'orders:reassign-expired';

    protected $description = 'Re-dispatch orders whose rider assignment expired without an accept (run every minute via scheduler).';

    public function handle(): int
    {
        $count = MatchingService::reassignExpired();
        $this->info("Re-dispatched {$count} expired order(s).");

        return self::SUCCESS;
    }
}
