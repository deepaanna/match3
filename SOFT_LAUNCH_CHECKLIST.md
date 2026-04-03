# Cryptid Clash: Echoes of the Unknown — Soft-Launch Checklist

## App Store Assets Needed

### Icons
- [ ] App icon 1024x1024 (iOS) — Bigfoot silhouette + match-3 grid motif
- [ ] App icon 512x512 (Android adaptive foreground)
- [ ] App icon 108x108 monochrome (Android notification)

### Screenshots (portrait 1290x2796 or 1242x2208)
- [ ] Home screen with title + Field Pass banner
- [ ] Gameplay mid-cascade (colorful board, booster visible)
- [ ] Ability activation with flash VFX
- [ ] Collection/Field Guide screen showing cryptid roster
- [ ] Map screen with region progression

### Store Listing Graphics
- [ ] Feature graphic 1024x500 (Google Play)
- [ ] Promotional banner 2048x1024 (optional — App Store)

### Splash / Boot
- [ ] Boot splash image 540x960 (already uses Godot default — replace with branded art)
- [ ] Loading screen tip text in boot_screen.gd

---

## ASO Keywords

**Primary (title/subtitle):** cryptid, match 3, puzzle, creature, collect

**Secondary (keyword field):**
bigfoot, mothman, nessie, yeti, jersey devil, chupacabra,
match three, tile puzzle, swap, cascade, combo,
monster, legend, mystery, investigate, evidence,
team, ability, battle pass, collect, discover

**Category:** Games > Puzzle
**Sub-category:** Games > Strategy (secondary)

---

## Privacy Policy

- [ ] Create a privacy policy page (host on GitHub Pages, Notion, or dedicated URL)
- [ ] Minimum contents: data collected (analytics events, device info), no PII, no ads yet
- [ ] Add URL to both store listings and Godot export settings
- [ ] Placeholder: `https://cryptidclash.github.io/privacy`

---

## TestFlight / Internal Test Steps

### iOS (TestFlight)
1. Open Godot Editor > Project > Export > Add iOS preset
2. Set `application/bundle_identifier` = `com.cryptidclash.echoes`
3. Set `application/short_version` = `0.1.0` (soft launch)
4. Set `application/version` = `1`
5. Configure signing: Apple Developer Team ID + provisioning profile
6. Export .xcodeproj, open in Xcode
7. Product > Archive > Distribute to App Store Connect
8. App Store Connect > TestFlight > Add internal testers
9. Testers install via TestFlight app on device

### Android (Internal Testing)
1. Open Godot Editor > Project > Export > Add Android preset
2. Set `package/unique_name` = `com.cryptidclash.echoes`
3. Set `version/code` = `1`, `version/name` = `0.1.0`
4. Configure keystore (debug or release)
5. Export .aab (Android App Bundle)
6. Google Play Console > Create app > Internal testing track
7. Upload .aab, add tester email list
8. Testers install via Play Store internal link

---

## Pre-Launch Verification

### Gameplay
- [ ] Levels 1-30 playable with no softlocks
- [ ] Cascades terminate naturally (no runaway loops)
- [ ] Boosters persist, glow, and activate correctly
- [ ] Shuffle system works (free first, paid/mercy after)
- [ ] All 7 goal types tracked (score, collect, ice, web, mana, mixed)
- [ ] Victory detonation fires on leftover moves

### Systems
- [ ] Save/load round-trips all 20+ PlayerData fields
- [ ] Daily login streak popup shows and grants rewards
- [ ] Energy regeneration works across app close/reopen
- [ ] Gacha pulls respect pity counters
- [ ] Team selection persists across sessions
- [ ] Discovery popups fire on first encounter only
- [ ] Analytics events print to console for all key moments

### Performance
- [ ] Stable 60fps on mid-range devices (Pixel 5 / iPhone 11)
- [ ] No memory leaks from piece pool cycling
- [ ] Scene transitions smooth (no frame drops during fade)

### Polish
- [ ] Battle Pass (Field Pass) displays tiers and allows claiming
- [ ] Debug menu accessible via DBG button or F12
- [ ] All SFX triggers connected (discovery, ability, cascade)
- [ ] Screen shake scales with cascade level
- [ ] Mist particles visible but subtle behind board

---

## Post-Launch Analytics to Monitor

| Metric | Target | Signal |
|--------|--------|--------|
| Level completion rate | >70% L1-5, >50% L6-15 | `level_completed` |
| Session length | >5 min average | session timer in analytics_manager |
| Daily retention (D1) | >40% | `daily_login` streak data |
| Energy wall hits | <3 per session | `energy_empty` count |
| Ability usage rate | >0.5 per level | `ability_used` per `level_started` |
| Shuffle frequency | <0.2 per level | `shuffle_used` per `level_started` |
| Battle Pass engagement | >20% open rate | `bp_reward_claimed` |
