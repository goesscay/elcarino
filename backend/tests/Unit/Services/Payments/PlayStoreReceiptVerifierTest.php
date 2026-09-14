<?php

namespace Tests\Unit\Services\Payments;

use App\Services\Payments\PlayStoreReceiptVerifier;
use App\Services\Payments\ReceiptVerificationException;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Not verified against a real Play Console service account (none
 * configured) — same status as FcmPushSender, whose OAuth2 JWT-bearer flow
 * this reuses verbatim for a different Google API.
 */
class PlayStoreReceiptVerifierTest extends TestCase
{
    /**
     * A throwaway 2048-bit RSA key generated only for this test (`openssl
     * genrsa`) — the JWT-bearer flow signs with RS256, so an arbitrary
     * string like "fake-key" isn't a valid private key and openssl rejects
     * it outright before the fake HTTP call is even reached. Not a real
     * credential of any kind.
     */
    private const TEST_PRIVATE_KEY = <<<'PEM'
        -----BEGIN PRIVATE KEY-----
        MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDONpTkHz1tOJ5j
        dcVw1BI0z2P5+RmwGoEzKn3r/eNccLrio5D6tho1Ptze+NXiw3apRHxNGK9sHNYN
        y3cu0Tp6kq1hEBhatYvHAVW3R0jk1y/8qJzCW0CETgQN1Qmf4Xe3pM0XlUrxRFbm
        kmXfpU9eptCqHI4+/UUPDQJTBGZeZBBXXreeuwHhPfuVfhO7Fi3PaEBocNUFASEi
        5IEnVO8k5lLl/1kE+lVHxF4yMYQOh1g9EzY0h4UFC+fTbBAZp48GSNWj00TqsXoy
        pVaLKPw7TBEAw5duEAFLBhBZ/KHQA7O3C8ezd/tpNXH+nWMbaZr+F61CTqXxjzJA
        e1NR9uphAgMBAAECggEAAKbpq79DihmCqGiP/Zv6nnjXZXCVHkgRdTl1GS6QQGXt
        /emZe64Fk57Ow0IA3x9SF4NY2Y1EyUuCVOVDS7UZgXL+j8XKLxD0BotFCVNi39Sk
        WUWEoxT3fpy9ZK87QTOoXr7G3TsnQQHkYU4b6H5U9NdM5gcUqFfmO3+8Y1wYIVZo
        6W9DnQRQHU50SBWOzJzvS+KiFP6jVcQnloaTkxhub7FqtOqIQD6JZ2Lryy917UoH
        DWAR2ng86axDiNmFD2doAuQKhz5O7db9BRwOe1j2LRjYwRtT5W3GNp8ZI3mM4z1P
        lEaYqCLRE7asKhf31o9RbSKgAqsPrYBX7OyytSelIQKBgQD86hMmZrP8wZ03MD3F
        1FX9uvVx+Ne9rKSHTr61aEerQJfnJvMc4SWsb+bNYrtw7mXyH29Iit6OOFhkSmWl
        k9lor7OkgdakUxf1fKvhCq63jCBiqQ773xTd9TivaxBsZn+H9vxECbPSMxNT9BXA
        vce3l4jw9QDPACdUoZXhY+nk2QKBgQDQuqVA69/acRT3RAEtILQfLr6PtkaHAXPm
        u4Afob83j2tQESyAt9DbxH3F+qbphJwq71ZXxfZS8yJyXRmWpsMitMOe6VvOvPD3
        ZaownMk3/h8+256K6ouvVT2oli3bTvlR8RWvw3p6RYheOEDyGucAZxyhd08AKh8Q
        vJIQ9A6cyQKBgGfPXFTiyvXwMqu4bWKKKVGgL6a8UTFVb6LqO3USfHhaZv9GCXvN
        Hj2NINskr3NHJykepfrMpVUS45UmxFoWOaKym7XmZUfFo4vrxFD2pYhJR/G3GqNf
        iZ0hTkcSVwdneulAA4OZx+l7dW98PIGEZDmDRX5B0jclBP/D41VEQXjhAoGBAJQw
        v1y9WlvbRzhaRr+EZX1yEYc0sRPuuxvIaSmMC5dlspnQ55inaJhvA6DI2TIXnUx6
        SgHdIYo45m7tnFoyIX6FehFbunun9yiePFtxJQck24gkIoacCPo9eZ40qW/3vNkp
        Ye08yrr+nNfP9oQtB25oxpH4g9UpEo8uYkG5FJrJAoGAU4yufAG+mu+37k9CkEJv
        SDRZNNMRVv1tMUQ52UwNaXAEJPFhsOhXpDIlrBSzMM0BrTtc2TmlhHadIZ0lWHbK
        ykxfeuabDzySzncgTPqZmy4yuIVf5/e+p2YH1SxxFJ+jH/JlOdDdLqWSwMjbq+kh
        pbno4H30L4rNaG2aeWaAodE=
        -----END PRIVATE KEY-----
        PEM;

    public function test_it_throws_when_unconfigured(): void
    {
        $this->expectException(ReceiptVerificationException::class);
        (new PlayStoreReceiptVerifier)->verify('{}');
    }

    public function test_it_throws_on_malformed_receipt_json(): void
    {
        $this->expectException(ReceiptVerificationException::class);
        (new PlayStoreReceiptVerifier('svc@example.iam.gserviceaccount.com', 'fake-key'))
            ->verify('not json');
    }

    public function test_a_valid_purchase_returns_a_verified_receipt(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response(['access_token' => 'fake-access-token']),
            'https://androidpublisher.googleapis.com/*' => Http::response(['expiryTimeMillis' => '1999999999000']),
        ]);

        $receipt = json_encode([
            'package_name' => 'com.mgs.elcarino',
            'subscription_id' => 'premium_monthly',
            'purchase_token' => 'token-abc',
        ]);

        $verified = (new PlayStoreReceiptVerifier('svc@example.iam.gserviceaccount.com', self::TEST_PRIVATE_KEY))->verify($receipt);

        $this->assertSame('token-abc', $verified->providerSubscriptionId);
        $this->assertSame(1999999999, $verified->expiresAt->getTimestamp());
    }
}
