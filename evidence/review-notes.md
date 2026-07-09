# Review Notes — Orders Cross-Stack Wiring

## Observed problems
- Staging data stack could not be created because the original template exported globally named values: `OrdersTableName` and `OrdersTableArn`.
- A proposed production data-stack cleanup was blocked because `checkout-api-prod` was still importing the legacy global exports.
- The sample prod change set shows a dangerous table rename: `OrdersTable` has `Replacement: "True"` caused by changing `TableName`.

## Implemented fix
- `templates/orders-table.yml` now always publishes per-environment exports:
  - `shopfluent-orders-${Environment}-OrdersTableName`
  - `shopfluent-orders-${Environment}-OrdersTableArn`
- `templates/checkout-api.yml` imports those same per-environment exports for:
  - `ORDERS_TABLE`
  - the Lambda role DynamoDB policy resource
- `CreateOrderFunctionName` is also exported with a per-environment export name to avoid API-stack output collisions.
- Both templates restrict `Environment` to `dev`, `staging`, or `prod` using `AllowedValues`.
- The DynamoDB physical name remains `shopfluent-orders-${Environment}`. For prod this remains `shopfluent-orders-prod`, so the live table is not renamed.
- `DeletionPolicy: Retain` and `UpdateReplacePolicy: Retain` remain on `OrdersTable`.

## Legacy export migration support
`orders-table.yml` includes a temporary `PublishLegacyExports` parameter. It defaults to `false` so new and non-prod deployments do not create global export names. It may only be set to `true` for `prod` and only during the migration window.

When enabled for prod, the template keeps the historical export names available:
- `OrdersTableName`
- `OrdersTableArn`

This lets production safely add the new scoped exports before moving `checkout-api-prod` away from the old imports.

## Safe production update sequence
1. Create and review a change set for `orders-data-prod` using the updated data template with `PublishLegacyExports=true`. This keeps the old exports and adds the new scoped exports.
2. Before executing, confirm the change set does not replace, delete, or remove `OrdersTable`. Acceptable changes are output/export additions and safe in-place property updates such as provisioned throughput if intended.
3. Execute the reviewed `orders-data-prod` change set.
4. Confirm both old and new prod exports exist and point to the same live table:
   - old: `OrdersTableName`, `OrdersTableArn`
   - new: `shopfluent-orders-prod-OrdersTableName`, `shopfluent-orders-prod-OrdersTableArn`
5. Create and review a change set for `checkout-api-prod` using the updated API template. Confirm its imports resolve to `shopfluent-orders-prod-*` and the Lambda environment variable `ORDERS_TABLE` resolves to `shopfluent-orders-prod`.
6. Execute the `checkout-api-prod` update.
7. Verify the legacy exports are no longer imported, for example with `aws cloudformation list-imports --export-name OrdersTableName` and `aws cloudformation list-imports --export-name OrdersTableArn`.
8. Create and review a final `orders-data-prod` change set with `PublishLegacyExports=false` to remove only the unused legacy outputs.
9. Execute the final data-stack cleanup only after the old exports have no importers.

## What to verify in the prod change set
Reject the change set if any of the following are true:
- `LogicalResourceId` is `OrdersTable` and `Action` is `Remove`.
- `LogicalResourceId` is `OrdersTable` and `Replacement` is `True` or `Conditional`.
- Any `OrdersTable` detail modifies `TableName`, key schema, or another property requiring recreation.
- The physical resource ID changes from `shopfluent-orders-prod`.
- `DeletionPolicy` or `UpdateReplacePolicy` is removed from the table template.

Expected safe signals:
- No `AWS::DynamoDB::Table` replacement.
- No `AWS::DynamoDB::Table` deletion.
- No `TableName` change.
- Scoped exports are added or legacy outputs are removed only after imports have moved.

## Out of scope
- Migrating to a different table design or discovery mechanism.
- Multi-account or StackSet rollout.
