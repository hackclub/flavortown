-- Flavortown Test Data Seeding Script
-- Run with: psql -d flavortown_development -f db/seed_test_data.sql
-- Or via Rails: bin/rails db:seed:test_data

BEGIN;

-- ============================================
-- USERS (10 test users with various roles)
-- ============================================
INSERT INTO users (id, email, display_name, first_name, last_name, slack_id, region, verification_status, ysws_eligible, session_token, created_at, updated_at)
VALUES
  (1, 'admin@test.com', 'Admin User', 'Admin', 'User', 'U001ADMIN', 'us', 'approved', true, 'session_admin_001', NOW(), NOW()),
  (2, 'reviewer@test.com', 'Project Reviewer', 'Project', 'Reviewer', 'U002REVIEW', 'us', 'approved', true, 'session_reviewer_002', NOW(), NOW()),
  (3, 'alice@test.com', 'Alice Dev', 'Alice', 'Developer', 'U003ALICE', 'us', 'approved', true, 'session_alice_003', NOW(), NOW()),
  (4, 'bob@test.com', 'Bob Builder', 'Bob', 'Builder', 'U004BOB', 'eu', 'approved', true, 'session_bob_004', NOW(), NOW()),
  (5, 'charlie@test.com', 'Charlie Coder', 'Charlie', 'Coder', 'U005CHARLIE', 'ca', 'approved', true, 'session_charlie_005', NOW(), NOW()),
  (6, 'diana@test.com', 'Diana Designer', 'Diana', 'Designer', 'U006DIANA', 'uk', 'approved', true, 'session_diana_006', NOW(), NOW()),
  (7, 'eve@test.com', 'Eve Engineer', 'Eve', 'Engineer', 'U007EVE', 'au', 'pending_review', false, 'session_eve_007', NOW(), NOW()),
  (8, 'frank@test.com', 'Frank Frontend', 'Frank', 'Frontend', 'U008FRANK', 'in', 'needs_submission', false, 'session_frank_008', NOW(), NOW()),
  (9, 'grace@test.com', 'Grace Gamer', 'Grace', 'Gamer', 'U009GRACE', 'us', 'approved', true, 'session_grace_009', NOW(), NOW()),
  (10, 'hank@test.com', 'Hank Hacker', 'Hank', 'Hacker', 'U010HANK', 'xx', 'approved', true, 'session_hank_010', NOW(), NOW())
ON CONFLICT DO NOTHING;

-- ============================================
-- USER ROLE ASSIGNMENTS
-- ============================================
-- super_admin: 0, admin: 1, fraud_dept: 2, project_certifier: 3, ysws_reviewer: 4, fulfillment_person: 5
INSERT INTO user_role_assignments (user_id, role, created_at, updated_at)
VALUES
  (1, 0, NOW(), NOW()), -- Admin User is super_admin
  (2, 3, NOW(), NOW()), -- Project Reviewer is project_certifier
  (2, 4, NOW(), NOW())  -- Project Reviewer is also ysws_reviewer
ON CONFLICT DO NOTHING;

-- Update has_roles flag for users with roles
UPDATE users SET has_roles = true WHERE id IN (1, 2);

-- ============================================
-- PROJECTS (8 projects with various statuses)
-- ============================================
INSERT INTO projects (id, title, description, repo_url, demo_url, project_type, ship_status, shipped_at, created_at, updated_at)
VALUES
  (1, 'Awesome Game Engine', 'A 2D game engine built from scratch with Rust', 'https://github.com/alice/game-engine', 'https://game-engine-demo.vercel.app', 'personal', 'shipped', NOW() - INTERVAL '5 days', NOW() - INTERVAL '30 days', NOW()),
  (2, 'Weather Dashboard', 'Real-time weather monitoring with beautiful charts', 'https://github.com/bob/weather-dash', 'https://weather.bob.dev', 'personal', 'shipped', NOW() - INTERVAL '10 days', NOW() - INTERVAL '45 days', NOW()),
  (3, 'Task Manager Pro', 'A collaborative task management app with real-time sync', 'https://github.com/charlie/task-pro', 'https://taskpro.io', 'personal', 'shipped', NOW() - INTERVAL '2 days', NOW() - INTERVAL '20 days', NOW()),
  (4, 'AI Art Generator', 'Generate stunning artwork using machine learning', 'https://github.com/diana/ai-art', 'https://ai-art.diana.dev', 'personal', 'pending_certification', NULL, NOW() - INTERVAL '7 days', NOW()),
  (5, 'Music Visualizer', 'Audio-reactive visuals for your music', 'https://github.com/eve/music-viz', NULL, 'personal', 'draft', NULL, NOW() - INTERVAL '3 days', NOW()),
  (6, 'Code Snippet Manager', 'Organize and share code snippets with syntax highlighting', 'https://github.com/frank/snippets', 'https://snippets.frank.dev', 'personal', 'shipped', NOW() - INTERVAL '15 days', NOW() - INTERVAL '60 days', NOW()),
  (7, 'Multiplayer Chess', 'Online chess with matchmaking and rankings', 'https://github.com/grace/chess', 'https://chess.grace.dev', 'personal', 'shipped', NOW() - INTERVAL '1 day', NOW() - INTERVAL '14 days', NOW()),
  (8, 'Terminal Portfolio', 'A portfolio website that looks like a terminal', 'https://github.com/hank/terminal-portfolio', 'https://hank.dev', 'personal', 'pending_certification', NULL, NOW() - INTERVAL '4 days', NOW())
ON CONFLICT DO NOTHING;

-- ============================================
-- PROJECT MEMBERSHIPS
-- ============================================
-- role: owner: 0, contributor: 1
INSERT INTO project_memberships (project_id, user_id, role, created_at, updated_at)
VALUES
  -- Project 1: Alice owns, Bob contributes
  (1, 3, 0, NOW(), NOW()),
  (1, 4, 1, NOW(), NOW()),
  -- Project 2: Bob owns
  (2, 4, 0, NOW(), NOW()),
  -- Project 3: Charlie owns, Diana and Eve contribute
  (3, 5, 0, NOW(), NOW()),
  (3, 6, 1, NOW(), NOW()),
  (3, 7, 1, NOW(), NOW()),
  -- Project 4: Diana owns
  (4, 6, 0, NOW(), NOW()),
  -- Project 5: Eve owns
  (5, 7, 0, NOW(), NOW()),
  -- Project 6: Frank owns
  (6, 8, 0, NOW(), NOW()),
  -- Project 7: Grace owns, Hank contributes
  (7, 9, 0, NOW(), NOW()),
  (7, 10, 1, NOW(), NOW()),
  -- Project 8: Hank owns
  (8, 10, 0, NOW(), NOW())
ON CONFLICT DO NOTHING;

-- Update membership counts
UPDATE projects SET memberships_count = (
  SELECT COUNT(*) FROM project_memberships WHERE project_memberships.project_id = projects.id
);

-- ============================================
-- POST DEVLOGS (journal entries for projects)
-- ============================================
INSERT INTO post_devlogs (id, body, duration_seconds, comments_count, likes_count, created_at, updated_at)
VALUES
  -- Project 1: Game Engine (Alice)
  (1, 'Started working on the rendering pipeline. Got basic sprite rendering working!', 7200, 0, 0, NOW() - INTERVAL '25 days', NOW()),
  (2, 'Implemented collision detection using quadtrees. Performance is great!', 10800, 0, 0, NOW() - INTERVAL '20 days', NOW()),
  (3, 'Added particle system support. Explosions look amazing now.', 5400, 0, 0, NOW() - INTERVAL '15 days', NOW()),
  -- Project 2: Weather Dashboard (Bob)
  (4, 'Integrated weather API and built the main dashboard layout', 14400, 0, 0, NOW() - INTERVAL '40 days', NOW()),
  (5, 'Added chart.js for beautiful visualizations. Users love it!', 9000, 0, 0, NOW() - INTERVAL '35 days', NOW()),
  -- Project 3: Task Manager (Charlie)
  (6, 'Implemented real-time sync with WebSockets. Collaboration works perfectly!', 18000, 0, 0, NOW() - INTERVAL '15 days', NOW()),
  (7, 'Built the drag-and-drop kanban board. Super satisfying to use.', 12600, 0, 0, NOW() - INTERVAL '10 days', NOW()),
  -- Project 4: AI Art Generator (Diana)
  (8, 'Trained custom Stable Diffusion model on art styles', 28800, 0, 0, NOW() - INTERVAL '5 days', NOW()),
  (18, 'Set up the React frontend with image upload and gallery view', 10800, 0, 0, NOW() - INTERVAL '6 days', NOW()),
  (19, 'Implemented style transfer pipeline. Can now blend any two art styles!', 18000, 0, 0, NOW() - INTERVAL '4 days', NOW()),
  -- Project 5: Music Visualizer (Eve)
  (11, 'Set up Web Audio API for frequency analysis. Getting cool waveform data!', 5400, 0, 0, NOW() - INTERVAL '2 days', NOW()),
  (12, 'Built first shader for reactive visuals. Colors pulse with the beat!', 7200, 0, 0, NOW() - INTERVAL '1 day', NOW()),
  -- Project 6: Code Snippet Manager (Frank)
  (13, 'Implemented syntax highlighting with Prism.js. Supports 50+ languages!', 10800, 0, 0, NOW() - INTERVAL '55 days', NOW()),
  (14, 'Added tagging system and search functionality. Finding snippets is instant.', 14400, 0, 0, NOW() - INTERVAL '50 days', NOW()),
  (15, 'Built sharing feature with unique URLs. Collaboration made easy!', 9000, 0, 0, NOW() - INTERVAL '45 days', NOW()),
  -- Project 7: Multiplayer Chess (Grace)
  (9, 'Built chess engine with minimax and alpha-beta pruning', 21600, 0, 0, NOW() - INTERVAL '10 days', NOW()),
  (10, 'Added ELO rating system and matchmaking queue', 16200, 0, 0, NOW() - INTERVAL '5 days', NOW()),
  -- Project 8: Terminal Portfolio (Hank)
  (16, 'Created terminal emulator with custom command parser', 12600, 0, 0, NOW() - INTERVAL '3 days', NOW()),
  (17, 'Added ASCII art generator for project screenshots. Looks retro!', 7200, 0, 0, NOW() - INTERVAL '2 days', NOW())
ON CONFLICT DO NOTHING;

-- ============================================
-- POSTS (connecting devlogs to projects)
-- ============================================
INSERT INTO posts (id, project_id, user_id, postable_type, postable_id, created_at, updated_at)
VALUES
  -- Project 1: Game Engine (Alice - user 3)
  (1, 1, 3, 'Post::Devlog', '1', NOW() - INTERVAL '25 days', NOW()),
  (2, 1, 3, 'Post::Devlog', '2', NOW() - INTERVAL '20 days', NOW()),
  (3, 1, 3, 'Post::Devlog', '3', NOW() - INTERVAL '15 days', NOW()),
  -- Project 2: Weather Dashboard (Bob - user 4)
  (4, 2, 4, 'Post::Devlog', '4', NOW() - INTERVAL '40 days', NOW()),
  (5, 2, 4, 'Post::Devlog', '5', NOW() - INTERVAL '35 days', NOW()),
  -- Project 3: Task Manager (Charlie - user 5)
  (6, 3, 5, 'Post::Devlog', '6', NOW() - INTERVAL '15 days', NOW()),
  (7, 3, 5, 'Post::Devlog', '7', NOW() - INTERVAL '10 days', NOW()),
  -- Project 4: AI Art Generator (Diana - user 6)
  (8, 4, 6, 'Post::Devlog', '8', NOW() - INTERVAL '5 days', NOW()),
  (18, 4, 6, 'Post::Devlog', '18', NOW() - INTERVAL '6 days', NOW()),
  (19, 4, 6, 'Post::Devlog', '19', NOW() - INTERVAL '4 days', NOW()),
  -- Project 5: Music Visualizer (Eve - user 7)
  (11, 5, 7, 'Post::Devlog', '11', NOW() - INTERVAL '2 days', NOW()),
  (12, 5, 7, 'Post::Devlog', '12', NOW() - INTERVAL '1 day', NOW()),
  -- Project 6: Code Snippet Manager (Frank - user 8)
  (13, 6, 8, 'Post::Devlog', '13', NOW() - INTERVAL '55 days', NOW()),
  (14, 6, 8, 'Post::Devlog', '14', NOW() - INTERVAL '50 days', NOW()),
  (15, 6, 8, 'Post::Devlog', '15', NOW() - INTERVAL '45 days', NOW()),
  -- Project 7: Multiplayer Chess (Grace - user 9)
  (9, 7, 9, 'Post::Devlog', '9', NOW() - INTERVAL '10 days', NOW()),
  (10, 7, 9, 'Post::Devlog', '10', NOW() - INTERVAL '5 days', NOW()),
  -- Project 8: Terminal Portfolio (Hank - user 10)
  (16, 8, 10, 'Post::Devlog', '16', NOW() - INTERVAL '3 days', NOW()),
  (17, 8, 10, 'Post::Devlog', '17', NOW() - INTERVAL '2 days', NOW())
ON CONFLICT DO NOTHING;

-- ============================================
-- SHIP CERTIFICATIONS (reviews of shipped projects)
-- ============================================
-- judgement: pending: 0, approved: 1, rejected: 2
INSERT INTO ship_certifications (id, project_id, reviewer_id, judgement, created_at, updated_at)
VALUES
  (1, 1, 2, 1, NOW() - INTERVAL '5 days', NOW()),  -- Game Engine approved
  (2, 2, 2, 1, NOW() - INTERVAL '10 days', NOW()), -- Weather Dashboard approved
  (3, 3, 2, 1, NOW() - INTERVAL '2 days', NOW()),  -- Task Manager approved
  (4, 4, NULL, 0, NOW() - INTERVAL '1 day', NOW()), -- AI Art pending
  (5, 6, 2, 1, NOW() - INTERVAL '15 days', NOW()), -- Snippet Manager approved
  (6, 7, 2, 1, NOW() - INTERVAL '1 day', NOW()),   -- Chess approved
  (7, 8, NULL, 0, NOW(), NOW())                     -- Terminal Portfolio pending
ON CONFLICT DO NOTHING;

-- ============================================
-- YSWS REVIEW SUBMISSIONS
-- ============================================
-- status: pending: 0, approved: 1, rejected: 2
INSERT INTO ysws_review_submissions (id, project_id, reviewer_id, status, reviewed_at, created_at, updated_at)
VALUES
  (1, 1, 2, 1, NOW() - INTERVAL '4 days', NOW() - INTERVAL '5 days', NOW()),  -- Game Engine approved
  (2, 2, 2, 1, NOW() - INTERVAL '9 days', NOW() - INTERVAL '10 days', NOW()), -- Weather Dashboard approved
  (3, 3, 2, 1, NOW() - INTERVAL '1 day', NOW() - INTERVAL '2 days', NOW()),   -- Task Manager approved
  (4, 6, 2, 1, NOW() - INTERVAL '14 days', NOW() - INTERVAL '15 days', NOW()), -- Snippet Manager approved
  (5, 7, 2, 1, NOW() - INTERVAL '12 hours', NOW() - INTERVAL '1 day', NOW())   -- Chess approved
ON CONFLICT DO NOTHING;

-- ============================================
-- YSWS REVIEW DEVLOG APPROVALS
-- ============================================
INSERT INTO ysws_review_devlog_approvals (id, ysws_review_submission_id, post_devlog_id, reviewer_id, approved, original_seconds, approved_seconds, reviewed_at, created_at, updated_at)
VALUES
  (1, 1, 1, 2, true, 7200, 7200, NOW() - INTERVAL '4 days', NOW() - INTERVAL '5 days', NOW()),
  (2, 1, 2, 2, true, 10800, 10800, NOW() - INTERVAL '4 days', NOW() - INTERVAL '5 days', NOW()),
  (3, 1, 3, 2, true, 5400, 5400, NOW() - INTERVAL '4 days', NOW() - INTERVAL '5 days', NOW()),
  (4, 2, 4, 2, true, 14400, 14400, NOW() - INTERVAL '9 days', NOW() - INTERVAL '10 days', NOW()),
  (5, 2, 5, 2, true, 9000, 9000, NOW() - INTERVAL '9 days', NOW() - INTERVAL '10 days', NOW()),
  (6, 3, 6, 2, true, 18000, 18000, NOW() - INTERVAL '1 day', NOW() - INTERVAL '2 days', NOW()),
  (7, 3, 7, 2, true, 12600, 12600, NOW() - INTERVAL '1 day', NOW() - INTERVAL '2 days', NOW()),
  (8, 5, 9, 2, true, 21600, 21600, NOW() - INTERVAL '12 hours', NOW() - INTERVAL '1 day', NOW()),
  (9, 5, 10, 2, true, 16200, 16200, NOW() - INTERVAL '12 hours', NOW() - INTERVAL '1 day', NOW())
ON CONFLICT DO NOTHING;

-- ============================================
-- COMMENTS (on devlogs)
-- ============================================
INSERT INTO comments (id, user_id, commentable_type, commentable_id, body, created_at, updated_at)
VALUES
  (1, 4, 'Post::Devlog', 1, 'This looks amazing! How did you handle sprite batching?', NOW() - INTERVAL '24 days', NOW()),
  (2, 3, 'Post::Devlog', 1, 'Thanks Bob! I use a texture atlas and batch by texture.', NOW() - INTERVAL '24 days', NOW()),
  (3, 5, 'Post::Devlog', 2, 'Quadtrees are such an elegant solution. Great choice!', NOW() - INTERVAL '19 days', NOW()),
  (4, 6, 'Post::Devlog', 4, 'The charts look beautiful! What library did you use?', NOW() - INTERVAL '39 days', NOW()),
  (5, 4, 'Post::Devlog', 4, 'Thanks Diana! I used Chart.js with custom theming.', NOW() - INTERVAL '39 days', NOW()),
  (6, 9, 'Post::Devlog', 6, 'WebSocket sync is so smooth! Any issues with reconnection?', NOW() - INTERVAL '14 days', NOW()),
  (7, 10, 'Post::Devlog', 8, 'The AI results are incredible. Training took how long?', NOW() - INTERVAL '4 days', NOW()),
  (8, 6, 'Post::Devlog', 8, 'About 8 hours on an A100. Worth every minute!', NOW() - INTERVAL '4 days', NOW())
ON CONFLICT DO NOTHING;

-- Update comment counts on devlogs
UPDATE post_devlogs SET comments_count = (
  SELECT COUNT(*) FROM comments 
  WHERE comments.commentable_type = 'Post::Devlog' 
  AND comments.commentable_id = post_devlogs.id
);

-- ============================================
-- LIKES (on devlogs)
-- ============================================
INSERT INTO likes (id, user_id, likeable_type, likeable_id, created_at, updated_at)
VALUES
  (1, 4, 'Post::Devlog', 1, NOW() - INTERVAL '24 days', NOW()),
  (2, 5, 'Post::Devlog', 1, NOW() - INTERVAL '23 days', NOW()),
  (3, 6, 'Post::Devlog', 1, NOW() - INTERVAL '22 days', NOW()),
  (4, 3, 'Post::Devlog', 4, NOW() - INTERVAL '38 days', NOW()),
  (5, 5, 'Post::Devlog', 4, NOW() - INTERVAL '37 days', NOW()),
  (6, 4, 'Post::Devlog', 6, NOW() - INTERVAL '14 days', NOW()),
  (7, 6, 'Post::Devlog', 6, NOW() - INTERVAL '13 days', NOW()),
  (8, 9, 'Post::Devlog', 6, NOW() - INTERVAL '12 days', NOW()),
  (9, 10, 'Post::Devlog', 8, NOW() - INTERVAL '4 days', NOW()),
  (10, 3, 'Post::Devlog', 9, NOW() - INTERVAL '9 days', NOW()),
  (11, 4, 'Post::Devlog', 9, NOW() - INTERVAL '8 days', NOW()),
  (12, 5, 'Post::Devlog', 10, NOW() - INTERVAL '4 days', NOW())
ON CONFLICT DO NOTHING;

-- Update like counts on devlogs
UPDATE post_devlogs SET likes_count = (
  SELECT COUNT(*) FROM likes 
  WHERE likes.likeable_type = 'Post::Devlog' 
  AND likes.likeable_id = post_devlogs.id
);

-- ============================================
-- VOTES (project ratings during ship events)
-- ============================================
-- category: default 0
INSERT INTO votes (id, user_id, project_id, score, category, reason, demo_url_clicked, repo_url_clicked, time_taken_to_vote, created_at, updated_at)
VALUES
  (1, 4, 1, 5, 0, 'Incredible game engine! The particle system is next level.', true, true, 120, NOW() - INTERVAL '4 days', NOW()),
  (2, 5, 1, 4, 0, 'Great work on collision detection. Very polished.', true, true, 90, NOW() - INTERVAL '4 days', NOW()),
  (3, 6, 1, 5, 0, 'The demo is so smooth. Professional quality work!', true, false, 60, NOW() - INTERVAL '4 days', NOW()),
  (4, 3, 2, 4, 0, 'Beautiful dashboard design. Love the animations.', true, true, 75, NOW() - INTERVAL '9 days', NOW()),
  (5, 5, 2, 4, 0, 'Very useful app. Would use daily!', true, false, 45, NOW() - INTERVAL '9 days', NOW()),
  (6, 3, 3, 5, 0, 'Real-time sync works flawlessly. Great UX!', true, true, 150, NOW() - INTERVAL '1 day', NOW()),
  (7, 4, 3, 5, 0, 'Best task manager I have seen. Love the kanban.', true, true, 100, NOW() - INTERVAL '1 day', NOW()),
  (8, 3, 7, 4, 0, 'Chess AI is really challenging. Great matchmaking.', true, true, 180, NOW() - INTERVAL '12 hours', NOW()),
  (9, 5, 7, 5, 0, 'The rating system works perfectly. Very addictive!', true, true, 200, NOW() - INTERVAL '12 hours', NOW()),
  (10, 6, 7, 4, 0, 'Love the multiplayer experience. Clean interface.', true, false, 80, NOW() - INTERVAL '12 hours', NOW())
ON CONFLICT DO NOTHING;

-- Update vote counts on users
UPDATE users SET votes_count = (
  SELECT COUNT(*) FROM votes WHERE votes.user_id = users.id
);

-- ============================================
-- USER HACKATIME PROJECTS (coding time tracking)
-- ============================================
INSERT INTO user_hackatime_projects (id, user_id, project_id, name, created_at, updated_at)
VALUES
  (1, 3, 1, 'game-engine', NOW() - INTERVAL '30 days', NOW()),
  (2, 4, 2, 'weather-dashboard', NOW() - INTERVAL '45 days', NOW()),
  (3, 5, 3, 'task-manager-pro', NOW() - INTERVAL '20 days', NOW()),
  (4, 6, 4, 'ai-art-gen', NOW() - INTERVAL '7 days', NOW()),
  (5, 7, 5, 'music-visualizer', NOW() - INTERVAL '3 days', NOW()),
  (6, 8, 6, 'code-snippets', NOW() - INTERVAL '60 days', NOW()),
  (7, 9, 7, 'multiplayer-chess', NOW() - INTERVAL '14 days', NOW()),
  (8, 10, 8, 'terminal-portfolio', NOW() - INTERVAL '4 days', NOW())
ON CONFLICT DO NOTHING;

-- ============================================
-- REPORTS (content moderation)
-- ============================================
-- status: pending: 0, reviewed: 1, dismissed: 2
INSERT INTO reports (id, reporter_id, project_id, reason, details, status, created_at, updated_at)
VALUES
  (1, 7, 6, 'spam', 'This project appears to contain copied code from another repository', 0, NOW() - INTERVAL '2 days', NOW()),
  (2, 8, 5, 'inappropriate_content', 'Project description contains inappropriate language', 1, NOW() - INTERVAL '5 days', NOW())
ON CONFLICT DO NOTHING;

-- ============================================
-- SHOP ITEMS (rewards store)
-- ============================================
INSERT INTO shop_items (id, name, description, type, ticket_cost, usd_cost, stock, enabled, enabled_us, enabled_eu, enabled_uk, enabled_ca, enabled_au, enabled_in, enabled_xx, hacker_score, created_at, updated_at)
VALUES
  (1, 'Hack Club Sticker Pack', 'A pack of 10 assorted Hack Club stickers', 'ShopItem', 100, 5.00, 500, true, true, true, true, true, true, true, true, 10, NOW(), NOW()),
  (2, 'LED Badge Kit', 'Build your own programmable LED badge', 'ShopItem', 500, 25.00, 100, true, true, true, true, true, false, false, false, 50, NOW(), NOW()),
  (3, 'Mechanical Keyboard', 'Custom mechanical keyboard with Cherry MX switches', 'ShopItem', 2000, 120.00, 20, true, true, true, true, true, true, false, false, 200, NOW(), NOW())
ON CONFLICT DO NOTHING;

-- ============================================
-- SHOP ORDERS
-- ============================================
INSERT INTO shop_orders (id, user_id, shop_item_id, quantity, aasm_state, frozen_item_price, created_at, updated_at)
VALUES
  (1, 3, 1, 1, 'fulfilled', 5.00, NOW() - INTERVAL '20 days', NOW()),
  (2, 4, 1, 2, 'fulfilled', 5.00, NOW() - INTERVAL '15 days', NOW()),
  (3, 5, 2, 1, 'pending', 25.00, NOW() - INTERVAL '2 days', NOW()),
  (4, 9, 3, 1, 'pending', 120.00, NOW() - INTERVAL '1 day', NOW())
ON CONFLICT DO NOTHING;

-- ============================================
-- LEDGER ENTRIES (point transactions)
-- ============================================
INSERT INTO ledger_entries (id, ledgerable_type, ledgerable_id, amount, reason, created_by, created_at, updated_at)
VALUES
  (1, 'User', 3, 500, 'Shipped first project', 'system', NOW() - INTERVAL '5 days', NOW()),
  (2, 'User', 3, 200, 'Project received 3 positive votes', 'system', NOW() - INTERVAL '4 days', NOW()),
  (3, 'User', 4, 500, 'Shipped first project', 'system', NOW() - INTERVAL '10 days', NOW()),
  (4, 'User', 5, 500, 'Shipped first project', 'system', NOW() - INTERVAL '2 days', NOW()),
  (5, 'User', 9, 500, 'Shipped first project', 'system', NOW() - INTERVAL '1 day', NOW()),
  (6, 'User', 9, 300, 'Project received 3 positive votes', 'system', NOW() - INTERVAL '12 hours', NOW())
ON CONFLICT DO NOTHING;

-- ============================================
-- RSVPS (event signups)
-- ============================================
INSERT INTO rsvps (id, email, ip_address, user_agent, created_at, updated_at)
VALUES
  (1, 'alice@test.com', '192.168.1.100', 'Mozilla/5.0 Chrome/120', NOW() - INTERVAL '7 days', NOW()),
  (2, 'bob@test.com', '192.168.1.101', 'Mozilla/5.0 Firefox/121', NOW() - INTERVAL '6 days', NOW()),
  (3, 'charlie@test.com', '192.168.1.102', 'Mozilla/5.0 Safari/17', NOW() - INTERVAL '5 days', NOW()),
  (4, 'newuser@example.com', '192.168.1.103', 'Mozilla/5.0 Chrome/120', NOW() - INTERVAL '1 day', NOW())
ON CONFLICT DO NOTHING;

-- ============================================
-- Reset sequences to avoid ID conflicts
-- ============================================
SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));
SELECT setval('projects_id_seq', (SELECT MAX(id) FROM projects));
SELECT setval('project_memberships_id_seq', (SELECT MAX(id) FROM project_memberships));
SELECT setval('post_devlogs_id_seq', (SELECT MAX(id) FROM post_devlogs));
SELECT setval('posts_id_seq', (SELECT MAX(id) FROM posts));
SELECT setval('comments_id_seq', (SELECT MAX(id) FROM comments));
SELECT setval('likes_id_seq', (SELECT MAX(id) FROM likes));
SELECT setval('votes_id_seq', (SELECT MAX(id) FROM votes));
SELECT setval('ship_certifications_id_seq', (SELECT MAX(id) FROM ship_certifications));
SELECT setval('ysws_review_submissions_id_seq', (SELECT MAX(id) FROM ysws_review_submissions));
SELECT setval('ysws_review_devlog_approvals_id_seq', (SELECT MAX(id) FROM ysws_review_devlog_approvals));
SELECT setval('user_hackatime_projects_id_seq', (SELECT MAX(id) FROM user_hackatime_projects));
SELECT setval('user_role_assignments_id_seq', (SELECT MAX(id) FROM user_role_assignments));
SELECT setval('reports_id_seq', (SELECT MAX(id) FROM reports));
SELECT setval('shop_items_id_seq', (SELECT MAX(id) FROM shop_items));
SELECT setval('shop_orders_id_seq', (SELECT MAX(id) FROM shop_orders));
SELECT setval('ledger_entries_id_seq', (SELECT MAX(id) FROM ledger_entries));
SELECT setval('rsvps_id_seq', (SELECT MAX(id) FROM rsvps));

COMMIT;

-- Summary of seeded data:
-- - 10 users (1 super_admin, 1 project_certifier/ysws_reviewer, 8 regular users)
-- - 8 projects with various ship statuses (all with devlogs)
-- - 12 project memberships (owners and contributors)
-- - 17 devlog posts with hours tracked (all projects have devlogs)
-- - 17 posts connecting devlogs to projects
-- - 7 ship certifications (5 approved, 2 pending)
-- - 5 YSWS review submissions with devlog approvals
-- - 8 comments on devlogs
-- - 12 likes on devlogs
-- - 10 votes on projects
-- - 8 hackatime project links
-- - 2 reports (1 pending, 1 reviewed)
-- - 3 shop items
-- - 4 shop orders
-- - 6 ledger entries
-- - 4 RSVPs
