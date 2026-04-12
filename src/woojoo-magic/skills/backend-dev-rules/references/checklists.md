# Checklists

## Schema Change Checklist

When modifying DB schema, verify all items:

```
□ 1. Update Shared Row model (single definition)
□ 2. Update Shared Param model (RPC parameters)
□ 3. Update Converter logic (Row ↔ Model)
□ 4. Verify CodingKeys match new column names
□ 5. Update all platform SELECT queries
□ 6. Update all platform INSERT/UPDATE queries
□ 7. Check widget data model impact
□ 8. Update access permission matrix
□ 9. Verify NULL constraint → Optional type match
□ 10. Update RPC function params at call sites
```

## PR Review Checklist

### Models
- [ ] New model defined in Shared? (platform-specific = REJECT)
- [ ] CodingKeys match DB schema?
- [ ] Optional types match DB NULL constraints?
- [ ] No dead/unused models introduced?

### Sync
- [ ] Conversion logic in Converter? (inline = REJECT)
- [ ] Retry logic uses shared RetryPolicy?
- [ ] Aggregation uses AggregationPolicy?
- [ ] Realtime self-loop prevention in place?

### Storage
- [ ] Widget data saved atomically (single key)?
- [ ] Migration code has removal version tag?
- [ ] App Groups key naming follows convention?

### Read/Write Parity
- [ ] Every SELECTed field has corresponding INSERT/UPDATE?
- [ ] Every SELECTed field is actually used? (unused = remove from query)
- [ ] Access permission matrix updated?

## Anti-Pattern Quick Reference

| # | Anti-Pattern | Fix |
|---|-------------|-----|
| 1 | Platform-specific Row model duplicates | Single definition in Shared |
| 2 | Inline conversion logic in service | Converter class in Shared |
| 3 | Multiple UserDefaults keys for related data | JSON single key |
| 4 | snake_case Swift properties | CodingKeys transformation |
| 5 | SELECT fields that are never used | Remove from query |
| 6 | READ fields with no corresponding WRITE | Add write logic or delete field |
| 7 | Different retry strategies per platform | Shared RetryPolicy |
| 8 | Permanent migration code | Version-tagged removal |
| 9 | print() debugging | os.Logger |
| 10 | Dead models left in codebase | grep → 0 refs → delete |

## Access Permission Matrix Template

Document this in ERD for every project:

```
| Table.Column            | Platform A | Platform B | Refresh   |
|-------------------------|:----------:|:----------:|-----------|
| daily_stats.*           | R/W        | R          | 1 min     |
| profiles.streak_count   | W          | R          | On event  |
| profiles.is_pro         | W          | R          | On purchase|
```

Every R cell must have at least one W cell. Every W cell must have at least one R cell (otherwise why write?).
