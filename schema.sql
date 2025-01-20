-- USERS
-- Note: This table contains user data. Users should only be able to view and update their own data.
create table users (
  -- UUID from auth.users
  id uuid references auth.users not null primary key,
  full_name text,
  avatar_url text,
  -- The customer's billing address, stored in JSON format.
  billing_address jsonb,
  -- Stores your customer's payment instruments.
  payment_method jsonb
);
alter table users enable row level security;
create policy "Can view own user data." on users for select using (auth.uid() = id);
create policy "Can update own user data." on users for update using (auth.uid() = id);


-- This trigger automatically creates a user entry when a new user signs up via Supabase Auth. 
create function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.users (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- CUSTOMERS
-- Note: This is a private table that contains a mapping of user IDs to Stripe customer IDs.
create table customers (
  -- UUID from auth.users
  id uuid references auth.users not null primary key,
  -- The user's customer ID in Stripe. User must not be able to update this.
  stripe_customer_id text
);
alter table customers enable row level security;
-- No policies as this is a private table that the user must not have access to.


-- SIZES
-- Note: Sizes are managed in the inventory manager.
create table sizes (
  -- Size ID, e.g. size_1234.
  id serial primary key,
  -- The size name, e.g. "Small", "Medium", "Large".
  name text not null unique,
  -- "Shirt", "Pants", "Shoes", etc.
  category text not null,
  -- "US", "EU", "UK", etc.
  system text not null
)
alter table sizes enable row level security;
create policy "Allow public read-only access." on sizes for select using (true);
create policy "Allow admins to insert sizes." on sizes for insert to admin with check (true);
create policy "Allow admins to update sizes." on sizes for update to admin using (true);
create policy "Allow admins to delete sizes." on sizes for delete to admin using (true);


-- COLORS
-- Note: Colors are managed in the inventory manager.
create table colors (
  -- Color ID, e.g. color_1234.
  id serial primary key,
  -- The color name, e.g. "Red", "Blue", "Green".
  name text not null unique
)
alter table colors enable row level security;
create policy "Allow public read-only access." on colors for select using (true);
create policy "Allow admins to insert colors." on colors for insert to admin with check (true);
create policy "Allow admins to update colors." on colors for update to admin using (true);
create policy "Allow admins to delete colors." on colors for delete to admin using (true);


-- PRODUCTS
-- Note: Products are created and managed in inventory manager. They are a compilation of product variants which are the actual Stripe products.
create table products (
  id serial primary key, -- Local product ID
  active boolean default false, -- Whether the product is currently available for purchase.
  name text not null, -- The product's name, meant to be displayable to the customer. Whenever this product is sold via a subscription, name will show up on associated invoice line item descriptions.
  -- The product's description, meant to be displayable to the customer. Use this field to optionally store a long form explanation of the product being sold for your own rendering purposes.
  description text,
  image text, -- A URL of the product image in Stripe, meant to be displayable to the customer.
);
alter table products enable row level security;
create policy "Allow public read-only access." on products for select using (true);
create policy "Allow admins to insert products." on products for insert to admin with check (true);
create policy "Allow admins to update products." on products for update to admin using (true);
create policy "Allow admins to delete products." on products for delete to admin using (true);

-- PRODUCT VARIANTS
-- Note: Product variants are managed in the inventory manager and synced to Stripe.
create table product_variants (
  id text primary key, -- Product ID from Stripe, e.g. prod_1234.
  product_id text references products on delete cascade, -- The ID of the product that this variant belongs to.
  size_id integer references sizes(id) not null, -- The size of the product variant.
  color_id integer references colors(id) not null, -- The color of the product variant.
  quantity integer default 0 check (quantity >= 0), -- The quantity of this variant in stock.
  created_at timestamp with time zone default timezone('utc'::text, now()) not null, -- Time at which the variant was created.
  images text[], -- A list of up to 8 URLs of images for this product, meant to be displayable to the customer.
  metadata jsonb -- Set of key-value pairs, used to store additional information about the object in a structured format.
  unique (product_id, size_id, color_id) -- Ensure one variant per size/color/product
);
alter table product_variants enable row level security;
alter table product_variants add constraint check_quantity_non_negative check (quantity >= 0); -- Ensure quantity is non-negative
create policy "Allow public read-only access." on product_variants for select using (true);
create policy "Allow admins to insert product variants." on product_variants for insert to admin with check (true);
create policy "Allow admins to update product variants." on product_variants for update to admin using (true);
create policy "Allow admins to delete product variants." on product_variants for delete to admin using (true);


-- PRODUCT CHANGES
-- Note: product changes are created when a product is updated.
create table product_changes (
  -- Product change ID, e.g. product_change_1234.
  id text primary key,
  -- The ID of the product that this change belongs to.
  product_id text references products,
  -- The ID of the product variant that this change belongs to.
  product_variant_id text references product_variants,
  -- The log of changes made to the product by the inventory manager.
  changelog jsonb,
  -- Time at which the product was updated.
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
);
alter table product_changes enable row level security;
create policy "Admins can view all product changes." on product_changes for select to admin using (true);


-- PRICES
-- Note: prices are created and managed in Stripe and synced to our DB via Stripe webhooks.
create table prices (
  -- Price ID from Stripe, e.g. price_1234.
  id text primary key,
  -- The ID of the product variant that this price belongs to. Stripe does not allow reusing prices between products and each variant will be a unique product. Can have multiple prices for a single product though (like sale prices).
  product_variant_id text references product_variants, 
  -- Whether the price can be used for new purchases.
  active boolean,
  -- A brief description of the price.
  description text,
  -- The unit amount as a positive integer in the smallest currency unit (e.g., 100 cents for US$1.00 or 100 for ¥100, a zero-decimal currency).
  unit_amount bigint,
  -- Three-letter ISO currency code, in lowercase.
  currency text check (char_length(currency) = 3),
  -- Set of key-value pairs, used to store additional information about the object in a structured format.
  metadata jsonb
);
alter table prices enable row level security;
create policy "Admins can view all prices." on prices for select to admin using (true);


-- ORDER STATUS
-- Note: order status are used to track the status of an order.
create table order_statuses (
  -- Status ID
  id serial primary key,
  -- Status name
  name text not null unique
);
insert into order_statuses (name) values
('pending_payment'), -- Order has been created but payment has not been confirmed.
('created'), -- Order has been created and paid for.
('processing'), -- Order is being processed (e.g. picking, packing).
('partially_shipped'), -- Order has been partially shipped.
('shipped'), -- Order has been shipped, but not yet delivered.
('out_for_delivery'), -- Order is out for delivery.
('delivered'), -- Order has been delivered.
('return_requested'), -- Customer has requested a return.
('return_shipped'), -- Customer has shipped the return.
('returned'), -- Order has been returned.
('partially_refunded'), -- Order has been partially refunded (for any reason).
('refunded'), -- Order has been refunded (for any reason).
('canceled'); -- Order has been canceled.


-- ORDERS
-- Note: orders are created when a customer makes a purchase.
create table orders (
  -- Order ID, e.g. order_1234.
  id text primary key,
  -- The ID of the user who placed the order.
  user_id uuid references auth.users not null,
  -- The status of the order.
  status order_status,
  -- The total amount of the order.
  total_amount bigint,
  -- Three-letter ISO currency code, in lowercase.
  currency text check (char_length(currency) = 3),
  -- Time at which the order was created.
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  -- Set of key-value pairs, used to store additional information about the object in a structured format.
  metadata jsonb
);
alter table orders enable row level security;
create policy "Can only view own orders." on orders for select using (auth.uid() = user_id);


-- ORDER ITEMS
-- Note: order items are the individual products within an order.
create table order_items (
  -- Order item ID, e.g. order_item_1234.
  id text primary key,
  -- The ID of the order that this item belongs to.
  order_id text references orders,
  -- The ID of the product that this item represents.
  product_variant_id text references product_variants,
  -- The quantity of the product.
  quantity integer,
  -- The unit amount of the product.
  unit_amount bigint,
  -- Three-letter ISO currency code, in lowercase.
  currency text check (char_length(currency) = 3),
  -- Set of key-value pairs, used to store additional information about the object in a structured format.
  metadata jsonb
);
alter table order_items enable row level security;
alter table order_items add constraint fk_order_items_order_id foreign key (order_id) references orders (id) on delete cascade;
create policy "Can only view own order items." on order_items for select using (auth.uid() = (select user_id from orders where orders.id = order_items.order_id));


-- ORDER CHANGES
-- Note: order changes are created when an order is updated.
create table order_changes (
  -- Order change ID, e.g. order_change_1234.
  id text primary key,
  -- The ID of the order that this change belongs to.
  order_id text references orders,
  -- The status of the order.
  status text,
  -- Time at which the order was updated.
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  -- Set of key-value pairs, used to store additional information about the object in a structured format.
  metadata jsonb
);


-- REALTIME SUBSCRIPTIONS
-- Only allow realtime listening on public tables.
drop publication if exists supabase_realtime;
create publication supabase_realtime for table products, prices, orders;