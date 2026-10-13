# 05 — Order pipeline

**Timer:** 25 minutes.

## Prompt

`POST /orders` must return 201 quickly. Payment, email, and stock updates may finish later. Peak is 10 000 orders per hour. Duplicates must not charge the card twice.

Write `docs/design/05-event-orders.md`.

## Constraints

- At-least-once delivery. You will see duplicates. Design idempotency keys.
- You may pick Service Bus / Event Hubs or SQS / SNS / EventBridge. Pick one pair and keep it.
- The HTTP API writes the order row first, then the event. Or it writes the outbox in the same transaction. Say which.
- Do not add Kafka unless you can say why a queue is not enough at 2.8 RPS.

## Capacity

What is 10 000 orders/hour in RPS? Use `orders_10k_per_hour_rps`. Image store: 2 000 000 objects × 200 000 bytes. Use `objects_2m_x_200kib_gb`.

## Hints

1. 10 000 / 3600 ≈ 2.78 RPS. This is not a streaming problem.
2. Idempotency key = `Idempotency-Key` header or `order_id` from the client.
3. Outbox: same Postgres transaction as the order row. A worker publishes. Inbox on the consumer stores processed IDs.

## Solution

<details>
<summary>Open after the timer or after you tried the hints.</summary>

**Rate:** `10000 / 3600 ≈ 2.78` RPS. A single queue (Azure Service Bus or Amazon SQS) is enough. Kafka is optional later for fan-out analytics, not for v1 charge-and-email.

**Path:** API validates → insert `orders` + `outbox` in one transaction → 201 → worker reads outbox → Service Bus / SQS → payment consumer (idempotent on `order_id`) → email consumer.

**Idempotency:** store `order_id` (or header) uniquely. A retry of `POST /orders` returns the same 201 body. The payment consumer records `order_id` before it captures funds. At-least-once plus a unique constraint beats "exactly-once" as a slogan.

**Images:** `2e6 × 200_000 / 1e9 = 400` GB. That is Blob / S3 capacity, not the queue.

**Refuse:** fire `httpx.post(payment)` inside the API request with no outbox. A timeout then double-charges or drops the order.

**Lab cost:** paper **USD 0.00**. A Service Bus basic or SQS queue is cents if you later apply it.

</details>
