-- Additive rewards only: existing unlocks, points, accounts and history are preserved.
begin;
insert into public.achievement_catalog (id,display_name,description,category,points,hidden,requirement,sort_order,is_active) values
('sessions_250','DEEP SPACE VOYAGER','累計250回プレイする。','basic',150,false,'{"type": "sessions", "count": 250}'::jsonb,1100,true),
('sessions_1000','THOUSAND ORBITS','累計1,000回プレイする。','basic',300,false,'{"type": "sessions", "count": 1000}'::jsonb,1101,true),
('perfect_40','PRECISION ACE','40問以上のセッションを正答率100%で完了する。','accuracy',180,false,'{"type": "perfect_session", "min_answers": 40}'::jsonb,1102,true),
('combo_100','CENTURY CHAIN','100コンボに到達する。','combo',200,false,'{"type": "combo", "value": 100}'::jsonb,1103,true),
('streak_30','MONTHLY ORBIT','30日連続でプレイする。','streak',200,false,'{"type": "streak_days", "days": 30}'::jsonb,1104,true),
('streak_60','ENDURING STAR','60日連続でプレイする。','streak',300,false,'{"type": "streak_days", "days": 60}'::jsonb,1105,true),
('all_modes_perfect_30','FIVE STAR PRECISION','主要5モードそれぞれで30問以上・正答率100%を達成する。','mode',300,false,'{"type": "all_modes_perfect", "modes": ["TEXT", "KEYS", "HD_TEXT", "HD_KEYS", "EAR_LINK"], "min_answers": 30}'::jsonb,1106,true),
('ear_perfect_40','DEEP LISTENER','EAR LINKで40問以上・正答率100%を達成する。','accuracy',250,false,'{"type": "perfect_session", "mode": "EAR_LINK", "min_answers": 40}'::jsonb,1107,true)
on conflict (id) do nothing;
insert into public.frame_catalog (id,display_name,tier,points_required,animated,hidden,unlock_rule,sort_order,is_active) values
('pulsar','PULSAR',9,0,true,false,'{"type": "achievement_combo", "ids": ["sessions_250", "perfect_40", "streak_30"]}'::jsonb,90,true),
('omega','OMEGA',10,0,true,false,'{"type": "achievement_combo", "ids": ["first_signal", "sessions_5", "sessions_20", "sessions_50", "sessions_100", "perfect_5", "perfect_10", "perfect_20", "combo_5", "combo_10", "combo_20", "combo_30", "text_10", "keys_10", "hyper_first", "ear_first", "all_modes", "interval_all_seen", "interval_80", "interval_90", "streak_3", "streak_7", "streak_14", "public_record", "rank_top10", "rank_podium", "rank_first", "hidden_ear_perfect", "hidden_all_mode_perfect", "hidden_combo_50", "hidden_singularity", "sessions_250", "sessions_1000", "perfect_40", "combo_100", "streak_30", "streak_60", "all_modes_perfect_30", "ear_perfect_40"]}'::jsonb,100,true)
on conflict (id) do nothing;
commit;
