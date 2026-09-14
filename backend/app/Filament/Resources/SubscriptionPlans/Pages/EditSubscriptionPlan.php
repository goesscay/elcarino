<?php

namespace App\Filament\Resources\SubscriptionPlans\Pages;

use App\Filament\Resources\SubscriptionPlans\Concerns\TransformsEntitlements;
use App\Filament\Resources\SubscriptionPlans\SubscriptionPlanResource;
use Filament\Resources\Pages\EditRecord;

/**
 * No DeleteAction — a plan with existing subscriptions can't be deleted
 * (subscriptions.plan_id has no cascade, by design: history must survive a
 * retired plan). `is_active` is the real "retire this plan" mechanism —
 * new signups stop, existing subscribers on it keep working.
 */
class EditSubscriptionPlan extends EditRecord
{
    use TransformsEntitlements;

    protected static string $resource = SubscriptionPlanResource::class;

    protected function mutateFormDataBeforeFill(array $data): array
    {
        return $this->expandEntitlements($data);
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
        return $this->collapseEntitlements($data);
    }
}
