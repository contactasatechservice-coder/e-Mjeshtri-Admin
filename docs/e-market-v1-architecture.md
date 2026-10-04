# e-Market V1 — frozen architecture

## Product decision

e-Market is a multi-vendor marketplace inside the e-Mjeshtri ecosystem.

- Citizen audience: home appliances and home-related products.
- Provider audience: professional tools and construction/service materials.
- Products can target citizen, provider, or both audiences.
- A service provider is not automatically a marketplace vendor.
- One account may hold citizen, provider, and market_vendor capabilities.
- e-Mjeshtri itself does not own inventory.
- Vendors own product inventory, fulfillment, shipping/pickup, returns, and direct V1 payment collection.
- Admin remains the final moderation and dispute authority.

## V1 application surfaces

### Citizen
Bottom navigation:
1. Home
2. Service orders
3. e-Market
4. Messages
5. Profile

### Provider
Bottom navigation:
1. Home
2. Requests / Jobs
3. e-Market
4. Messages
5. Profile

### e-Market seller panel
Separate seller-facing interface for:
- vendor profile and verification
- products
- product media
- variants and attributes
- inventory
- vendor orders
- shipping
- promotions
- returns
- finance / commissions
- subscription
- notifications
- settings

### Admin
Admin owns:
- vendor approval / suspension
- product moderation
- categories and brands
- order oversight
- returns / disputes
- vendor subscriptions
- marketplace commissions
- reports
- audit log
- global e-Market settings

## Catalog rules

Every product belongs to exactly one vendor.

Product audience:
- citizen
- provider
- both

Product status lifecycle:
- draft
- pending_review
- active
- rejected
- inactive
- archived

Vendor status lifecycle:
- pending
- approved
- rejected
- suspended
- archived

New products require Admin approval unless the vendor has explicit auto-approval permission.

## Multi-vendor cart and checkout

One user-facing cart may contain products from multiple vendors.

At checkout:
- one market_orders record is created
- one market_vendor_orders record is created for each vendor
- market_order_items snapshots product/variant name, SKU, price, warranty and installation category
- stock is reserved transactionally
- delivery fee is calculated per vendor
- payment is represented per vendor order

V1 payment methods:
- cash on delivery
- bank transfer

Card payments are reserved for a later version.

## Installation bridge

Products may optionally reference service_categories through installation_category_id.

Example:
- Air conditioner -> AC installer
- Security camera -> security installer
- Sink / faucet -> plumber

The customer can later start a service request directly from the purchased product.

## Price model

Products support:
- retail_price
- professional_price
- compare_at_price

Provider users receive professional_price where configured.

The schema is compatible with future bulk pricing without changing order snapshots.

## Inventory

Stock is vendor-owned.

Inventory movements are recorded for:
- stock_in
- sale
- reservation
- release
- return
- adjustment
- damage

Checkout reserves stock before order creation completes.

## Returns

Return lifecycle:
- requested
- vendor_approved
- vendor_rejected
- escalated
- admin_approved
- admin_rejected
- received
- refunded
- closed

Admin is the final escalation authority.

## Reviews

Separate review entities:
- market_product_reviews
- market_vendor_reviews

Only delivered-purchase verification will be allowed before public V1 launch.

## Security

- All marketplace tables use RLS.
- Catalog reads require active/approved products and vendors.
- Vendor writes require active membership and matching vendor ownership.
- Admin moderation uses security-definer RPCs protected by the existing admin authorization layer.
- Checkout price and stock calculations are server-side.
- Product images and vendor documents use dedicated private storage buckets.

## V1 non-goals

Not part of V1:
- used-product classifieds
- auction
- live selling
- wallet / loyalty points
- automated seller payouts
- payment-card split payments
- dropshipping automation
- AI recommendations
- third-party courier APIs
- complex coupon engine

The schema should remain compatible with these future features where practical.
