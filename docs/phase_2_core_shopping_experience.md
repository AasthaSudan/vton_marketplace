# Clothsy Shop App — Phase 2: Core Shopping Experience

## Goal
Build the browsing flow end to end with real data: onboarding, home, categories, product listing, search, product detail, wishlist and cart. By the end of this phase a user can discover products and fill a cart.

## Depends On
Phase 1 design system, router shell and component library.

## Data Layer
- Connect to Shopify Storefront API: products, collections, variants (size/colour), images, prices, compare-at prices, inventory.
- Repository methods needed: featured banners, categories/collections, products by collection with pagination, product by handle/id, search with filters, recommendations.
- Cache home feed and last-viewed products locally for instant launch and offline fallback.
- Pagination: cursor-based infinite scroll, 20 items per page.
- Map Shopify data into clean domain entities (Product, Variant, Collection, Banner, CartLine) so UI never sees Shopify-specific shapes.

## Screens

### 1. Splash and Onboarding (reference screen 1)
- Splash with Clothsy mark on cream background.
- Onboarding: sparkle icon, "DISCOVER" label, large serif headline with one word in lilac/plum emphasis ("Your Style, Your Story" style copy — adapt to Clothsy: "See Yourself In Every Outfit").
- Staggered image collage with rounded cards and vertical stripe accents.
- Page indicator dots, "Get Started" pill button with arrow.
- 2–3 slides, one of them introducing virtual try-on.
- Show only on first launch.

### 2. Home (reference screen 2)
- Top bar: menu icon, brand wordmark centred, search icon, cart icon with badge.
- Hero carousel: dark plum banners ("New Season / New Styles / Up to 40% off") with auto-scroll and dots. Banners managed from the backend, not hardcoded.
- Category row: circular icon tiles (All, Men, Women, Shoes, Bags, etc.), horizontally scrollable, selected state filled.
- "Best Picks" section with horizontal product cards, discount badge, heart icon.
- Additional sections: New Arrivals, Trending, Recently Viewed.
- Exclusive offer strip at bottom (soft lilac).
- Pull-to-refresh.

### 3. Category / Product Listing
- Grid of product cards (2 columns), infinite scroll.
- Sticky filter/sort bar: sort by price, newest, popularity; filter by size, colour, price range, category.
- Filters open in a bottom sheet; applied filters shown as removable chips.
- Grid/list toggle optional.

### 4. Search
- Search field with debounce.
- Recent searches (stored locally) and trending searches.
- Live suggestions while typing, then full results grid with the same filters as listing.
- Clear no-results state with suggested categories.

### 5. Product Detail Page (reference screen 3)
- Large image in an arched/rounded frame on a soft background, swipeable gallery with counter ("1/4"), pinch to zoom in full-screen view.
- Top: back button, wishlist heart.
- Brand label, serif product name, rating row.
- Price row: price, strikethrough, discount pill ("20% OFF").
- Size selector and colour swatches — selecting a variant updates price, image and stock.
- Description with "Read More" expand.
- Extra sections: size guide sheet, delivery/returns info, "You may also like".
- Sticky bottom bar: "Add to Cart" (outlined) and "Buy Now" (filled plum).
- Reserve a "Try It On" button slot beside Add to Cart (activated in Phase 4).
- Hero animation from product card image.

### 6. Wishlist
- Grid of saved items, move to cart, remove.
- Works for guests (local) and syncs to account after login (Phase 3).

### 7. Cart
- Line items with image, name, variant, price, quantity stepper, remove (swipe to delete).
- Coupon code field.
- Price summary: subtotal, discount, shipping, total.
- Empty-cart state with "Continue shopping".
- Use Shopify Cart API so the cart persists server-side and carries into checkout.
- Checkout button (wired in Phase 3).

## Cross-Cutting
- Skeleton loaders on every network screen.
- Error states with retry; offline banner when no connectivity.
- Deep links: product and collection URLs open the right screen.
- Analytics events: view item, view list, search, add to wishlist, add to cart.
- Image optimisation: request correctly sized images from the CDN per device width.

## Deliverables
1. Onboarding, Home, Listing, Search, PDP, Wishlist, Cart — all on live data.
2. Cart and wishlist state shared app-wide via Riverpod.
3. Deep link handling for products and collections.
4. Unit tests for repositories and providers; widget tests for Home, PDP and Cart.

## Acceptance Criteria
- Home loads in under 1.5 seconds on a mid-range Android device with cache warm.
- Variant selection always shows correct price, image and stock.
- Cart count badge updates instantly everywhere.
- Scrolling stays at 60 fps on product grids.
- Every screen handles loading, empty, error and offline states.
