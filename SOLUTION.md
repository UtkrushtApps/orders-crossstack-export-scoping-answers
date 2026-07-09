# Solution Steps

1. Add `AllowedValues` to the `Environment` parameter in both CloudFormation templates so only `dev`, `staging`, and `prod` can be deployed.

2. Change the data-stack steady-state exports from global names (`OrdersTableName`, `OrdersTableArn`) to environment-scoped names such as `shopfluent-orders-${Environment}-OrdersTableName` and `shopfluent-orders-${Environment}-OrdersTableArn`.

3. Keep the DynamoDB table resource stable: do not change the `OrdersTable` logical ID, do not change the `TableName` pattern, and retain `DeletionPolicy: Retain` plus `UpdateReplacePolicy: Retain`.

4. Add a temporary `PublishLegacyExports` parameter to the data template. Default it to `false`, restrict it to `true` or `false`, and add a rule so it can only be enabled for `prod`.

5. Keep the original legacy output logical IDs (`OrdersTableName`, `OrdersTableArn`) as conditional outputs when `PublishLegacyExports=true`. This lets existing prod imports keep working during migration while new environments avoid export collisions.

6. Update the checkout API template so the Lambda IAM policy imports `shopfluent-orders-${Environment}-OrdersTableArn` and the `ORDERS_TABLE` environment variable imports `shopfluent-orders-${Environment}-OrdersTableName`.

7. Scope the checkout API output export name as well, for example `shopfluent-checkout-${Environment}-CreateOrderFunctionName`, so checkout stacks can also coexist per environment.

8. Update the data-stack parameter files to include `PublishLegacyExports=false` for normal steady-state deployments. Leave checkout parameter files using supported environment values.

9. Document the safe production rollout: first update `orders-data-prod` with `PublishLegacyExports=true`, then update `checkout-api-prod` to the scoped imports, verify old exports have no importers, and finally update `orders-data-prod` with `PublishLegacyExports=false`.

10. Before applying any production data-stack change set, verify that `OrdersTable` has no `Remove` action, no `Replacement: True` or `Replacement: Conditional`, no `TableName` change, and no change to the physical table ID `shopfluent-orders-prod`.

