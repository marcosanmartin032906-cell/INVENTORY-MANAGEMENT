-- Inventory System: run once in Supabase (SQL Editor -> New query -> Run).
-- This only touches the inventory tables. The first line erases them so you can re-run safely.
drop table if exists movements, products cascade;
drop function if exists move_stock(bigint, text, int, text);

create table products(
  id bigint generated always as identity primary key,
  sku text unique not null,
  name text not null,
  category text not null,
  price numeric(10,2) not null default 0 check (price >= 0),
  quantity int not null default 0 check (quantity >= 0),
  reorder_level int not null default 10 check (reorder_level >= 0)
);

create table movements(
  id bigint generated always as identity primary key,
  product_id bigint not null references products(id) on delete cascade,
  type text not null check (type in ('in','out')),
  qty int not null check (qty > 0),
  note text,
  created_at timestamptz not null default now()
);

-- Stock in/out in one safe step: changes the quantity and logs the movement together.
create function move_stock(p_product bigint, p_type text, p_qty int, p_note text default '')
returns void language plpgsql as $$
begin
  if p_qty is null or p_qty <= 0 then raise exception 'Quantity must be more than zero'; end if;
  if p_type = 'in' then
    update products set quantity = quantity + p_qty where id = p_product;
  elsif p_type = 'out' then
    update products set quantity = quantity - p_qty where id = p_product and quantity >= p_qty;
    if not found then raise exception 'Not enough stock for this item'; end if;
  else
    raise exception 'Type must be in or out';
  end if;
  insert into movements(product_id, type, qty, note) values (p_product, p_type, p_qty, p_note);
end $$;

grant execute on function move_stock(bigint, text, int, text) to anon, authenticated;

-- Open access for a class project. Add a login before using this for real.
alter table products enable row level security;
alter table movements enable row level security;
create policy "open" on products for all using (true) with check (true);
create policy "open" on movements for all using (true) with check (true);

-- Sample data
insert into products(sku,name,category,price,quantity,reorder_level) values
('SKU-001','Notebook A5','Stationery',45,120,30),
('SKU-002','Ballpen Black (box)','Stationery',180,35,10),
('SKU-003','Bottled Water 500ml','Beverages',15,8,24),
('SKU-004','Instant Noodles','Food',12,0,20),
('SKU-005','Hand Sanitizer 250ml','Health',85,42,15),
('SKU-006','USB Flash Drive 32GB','Electronics',320,18,5),
('SKU-007','Phone Charger','Electronics',250,6,8),
('SKU-008','Rice 5kg','Food',290,60,15),
('SKU-009','Face Mask (box)','Health',120,25,10),
('SKU-010','Bond Paper A4','Stationery',260,14,10);

insert into movements(product_id,type,qty,note,created_at) values
(1,'in',150,'Opening stock',now() - interval '6 days'),
(1,'out',30,'Sold to school',now() - interval '4 days'),
(3,'in',40,'Supplier delivery',now() - interval '5 days'),
(3,'out',32,'Weekend sales',now() - interval '2 days'),
(4,'in',50,'Opening stock',now() - interval '6 days'),
(4,'out',50,'Sold out',now() - interval '1 day'),
(7,'in',15,'Supplier delivery',now() - interval '3 days'),
(7,'out',9,'Sales',now() - interval '1 day'),
(8,'in',60,'Opening stock',now() - interval '6 days');
