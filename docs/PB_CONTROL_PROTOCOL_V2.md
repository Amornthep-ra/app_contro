# PB Control Protocol v2

This contract is mandatory for every board controlled by PB Controller 2.1.0
and later. A board that only implements the older packet format may be
discovered, but the app will not start control.

## Safety requirement

The firmware starts in a stopped state. It must set every actuator/control
output to zero and clear input state when any of these occurs:

- BLE client disconnects or authentication fails;
- no valid authenticated control packet arrives for **400 ms**;
- a packet has a bad MAC, invalid length, or a stale/repeated sequence number.

The watchdog must run independently from BLE callbacks. Only a valid v2
joystick packet refreshes it. A valid `STOP` packet stops immediately and does
not enable later movement by itself.

## Pairing and setup messages

Each board has an immutable `boardId` and a unique random 8–16 character
Crockford Base32 pairing code (for example `7K9M-2PQT`), printed on its sticker. Eight characters is the
recommended balance of usability and security for local BLE control. The app and firmware
derive the 32-byte secret as SHA-256 of `PB2|PAIR|<normalized-code>`, where
hyphens/spaces are removed and letters are uppercase. Do not use I, L, O, or U.

All setup messages are UTF-8 lines terminated by `\n` and are reassembled by
both sides before parsing.

1. App sends `PB2:HELLO:<appNonce>` where the nonce is 16 random bytes in hex.
2. Board sends `PB2:CAPS:2:<boardId>:<model>:<firmware>:<boardNonce>:<tag>`.
   `tag` is HMAC-SHA256(secret, `PB2|CAPS|boardId|model|firmware|appNonce|boardNonce`) in lowercase hex.
3. App verifies the tag and sends `PB2:AUTH:<tag>`, where `tag` is
   HMAC-SHA256(secret, `PB2|AUTH|boardId|appNonce|boardNonce`).
4. Board validates it, chooses a fresh session ID, and replies
   `PB2:OK:<sessionId>:<tag>`. The final tag is
   HMAC-SHA256(secret, `PB2|OK|boardId|appNonce|boardNonce|sessionId`).

Derive the session key as HMAC-SHA256(secret,
`PB2|SESSION|boardId|appNonce|boardNonce|sessionId`). Never log the secret,
nonces, tags, or derived session key.

## Control packet

Every binary packet is:

`AA 55 02 type sequence(4-byte big-endian) payloadLength payload tag(8 bytes)`

`tag` is the first 8 bytes of HMAC-SHA256(sessionKey, all preceding bytes).
Sequence starts at 1 for each session and must strictly increase. Type `01` is
joystick with six-byte payload `lx ly rx ry buttonsLow buttonsHigh`; type `02`
is `STOP` with an empty payload.

Accept only one authenticated client at a time. Invalidate the session on BLE
disconnect, watchdog expiry, or any authentication/control validation error.
