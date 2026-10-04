<?php

namespace Tests\Feature;

use App\Models\FareSetting;
use App\Models\Otp;
use App\Models\Payout;
use App\Models\Zone;

class AdminPanelTest extends SwiftDropTestCase
{
    public function test_guest_is_redirected_to_admin_login(): void
    {
        $this->get('/admin')->assertRedirect('/admin/login');
        $this->get('/admin/riders')->assertRedirect('/admin/login');
        $this->get('/admin/orders')->assertRedirect('/admin/login');
        $this->get('/admin/zones')->assertRedirect('/admin/login');
        $this->get('/admin/fare')->assertRedirect('/admin/login');
        $this->get('/admin/payouts')->assertRedirect('/admin/login');
    }

    public function test_non_admin_cannot_access_panel(): void
    {
        $customer = $this->makeCustomer();

        $this->actingAs($customer)->get('/admin')->assertForbidden();
        $this->actingAs($customer)->get('/admin/riders')->assertForbidden();
    }

    public function test_admin_login_rejects_unknown_phone(): void
    {
        $this->post('/admin/login', ['phone' => '9876543210'])
            ->assertSessionHasErrors('phone');
    }

    public function test_admin_can_login_via_otp_and_see_dashboard(): void
    {
        $this->makeAdmin('9000000001');

        $this->post('/admin/login', ['phone' => '9000000001'])
            ->assertRedirect('/admin/login/verify');

        $code = Otp::where('phone', '9000000001')->latest('id')->first()->code;

        $this->post('/admin/login/verify', ['code' => $code])
            ->assertRedirect('/admin');

        $this->get('/admin')
            ->assertOk()
            ->assertSee('Dashboard')
            ->assertSee('Orders today');
    }

    public function test_admin_login_rejects_wrong_code(): void
    {
        $this->makeAdmin('9000000001');

        $this->post('/admin/login', ['phone' => '9000000001']);

        $this->post('/admin/login/verify', ['code' => '0000'])
            ->assertSessionHasErrors('code');

        $this->get('/admin')->assertRedirect('/admin/login');
    }

    public function test_admin_can_verify_rider_from_panel(): void
    {
        $admin = $this->makeAdmin();
        $rider = $this->makeRider('9876543211', approved: false, online: false);

        $this->actingAs($admin)
            ->get("/admin/riders/{$rider->id}")
            ->assertOk()
            ->assertSee('Test Rider');

        $this->actingAs($admin)
            ->post("/admin/riders/{$rider->id}/verify", ['approved' => true])
            ->assertRedirect();

        $this->assertSame('approved', $rider->riderProfile->fresh()->verification_status);
    }

    public function test_admin_can_toggle_zone(): void
    {
        $admin = $this->makeAdmin();
        $zone = Zone::where('name', 'Kukatpally')->first();
        $this->assertTrue($zone->is_active);

        $this->actingAs($admin)
            ->post("/admin/zones/{$zone->id}/toggle")
            ->assertRedirect('/admin/zones');

        $this->assertFalse($zone->fresh()->is_active);
    }

    public function test_admin_can_update_fare_settings(): void
    {
        $admin = $this->makeAdmin();

        $this->actingAs($admin)
            ->post('/admin/fare', ['platform_commission_pct' => '8'])
            ->assertRedirect('/admin/fare');

        $this->assertSame('8', FareSetting::get('platform_commission_pct'));
    }

    public function test_admin_can_mark_payout_paid(): void
    {
        $admin = $this->makeAdmin();
        $rider = $this->makeRider();

        $payout = Payout::create([
            'rider_id' => $rider->id,
            'period_start' => now()->startOfMonth()->toDateString(),
            'period_end' => now()->toDateString(),
            'trips' => 3,
            'amount_paise' => 5000,
            'status' => 'pending',
        ]);

        $this->actingAs($admin)
            ->post("/admin/payouts/{$payout->id}/mark-paid", ['bank_ref' => 'NEFT123'])
            ->assertRedirect('/admin/payouts');

        $payout->refresh();
        $this->assertSame('paid', $payout->status);
        $this->assertSame('NEFT123', $payout->bank_ref);
        $this->assertNotNull($payout->paid_at);
    }
}
