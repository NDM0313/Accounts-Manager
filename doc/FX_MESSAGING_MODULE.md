# FX Internal Team Messaging

**Status:** Schema proposed (not applied until migration approved)  
**Supabase project:** `ygidlcqhupmxvsdjmvnf` only

## Purpose

Staff communicate inside the app about deals, parties, transactions, payments, and proofs. Branch-scoped; not customer-facing.

## Conversation types

| Type | Context FK | Auto-title example |
|------|------------|-------------------|
| `direct` | — | User names |
| `deal` | `context_deal_id` | Deal DL-… |
| `party` | `context_party_id` | Party name |
| `transaction` | `context_transaction_id` | Txn ref |
| `company` | — | Branch team room |

## Message types (M1: text + refs; M2: files)

M1: `text`, `deal_ref`, `transaction_ref`, `party_ref`, `system`  
M2: `image`, `file`, `link` (voice deferred)

## Tables

- `fx_conversations` — header, branch_id, type, context FKs, last_message_at
- `fx_conversation_members` — user_id, last_read_at, unread_count
- `fx_messages` — body, message_type, metadata JSONB, sender_id

## RLS

- SELECT: member of conversation OR `can_manage_messaging` (admin)
- INSERT message: member + same branch
- Members managed by conversation creator or admin

## Realtime

Enable Supabase Realtime publication on `fx_messages` for live room updates (first Realtime usage in app).

## Storage (M2)

Path: `{branchId}/messages/{conversationId}/{filename}` in `fx-attachments` bucket.  
Extend `fx_attachments.message_id` FK.

## RPCs

| RPC | Phase |
|-----|-------|
| `fx_list_conversations` | M1 |
| `fx_get_or_create_entity_conversation` | M1 |
| `fx_send_message` | M1 |
| `fx_mark_conversation_read` | M1 |
| `fx_list_messages` | M1 |

## Flutter routes

| Route | Screen |
|-------|--------|
| `/messages` | Inbox + unread badges |
| `/messages/:id` | Conversation room |

Embedded panels:

- `EntityChatPanel` on deal detail, transaction detail, party ledger

Feature flag: `FeatureFlags.messagingEnabled`.

## Permissions

- `can_manage_messaging` — admin: all branch rooms
- `can_access_fx_ledger` — join/send in rooms where member

## Migration (proposal)

`202606230003_fx_messaging_module.sql`  
`202606230004_fx_attachments_remittance_message.sql`

Verify: `supabase/scripts/verify_messaging_module.sql`

## Testing

- `test/widgets/messaging/conversation_room_test.dart`
