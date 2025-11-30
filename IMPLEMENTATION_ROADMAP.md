# Two Tangles - Implementation Roadmap

## Overview

This document provides a prioritized roadmap for implementing all requested features and fixes. Each item links to detailed analysis documents.

## Completed ✅

### 1. K1 Hold Fix
**Status**: ✅ Complete
**Details**: [K1_HOLD_FIX.md](K1_HOLD_FIX.md)
**Summary**: Removed clock start/stop from K1 so hold modifier works correctly for encoders

### 2. Source Relocation
**Status**: ✅ Complete
**Details**: [SOURCE_RELOCATION_CHANGES.md](SOURCE_RELOCATION_CHANGES.md)
**Summary**: Moved sources from column 4 to 3×3 grid with value-based LED brightness

### 3. Analysis Documents
**Status**: ✅ Complete
**Files Created**:
- SHIFT_REGISTER_ANALYSIS.md
- UI_IMPROVEMENTS_ANALYSIS.md
- PULSE_ANIMATION_REDESIGN.md
- SOURCE_LED_BRIGHTNESS_FIX.md
- RANDOM_SOURCE_TIMING_FIX.md
- PITCH_QUANTIZATION_DESIGN.md
- PATCH_VISUALIZATION_DESIGN.md

---

## Quick Wins (1-2 hours each)

These are high-impact changes with low complexity. Recommend implementing first.

### 4. Fix Source LED Brightness When Patched
**Priority**: 🔴 High
**Complexity**: 🟢 Low
**Details**: [SOURCE_LED_BRIGHTNESS_FIX.md](SOURCE_LED_BRIGHTNESS_FIX.md)

**Problem**: Source LEDs show patch weight instead of source value
**Solution**: Add conditional to use source value for source patches
**Impact**: Users can see source strength even when patched
**Estimate**: 30 minutes

**Files**: `two_tangles.lua` line ~2260

---

### 5. Fix Random Source Animation Timing
**Priority**: 🟡 Medium
**Complexity**: 🟢 Low
**Details**: [RANDOM_SOURCE_TIMING_FIX.md](RANDOM_SOURCE_TIMING_FIX.md)

**Problem**: Random source only animates when clock is running
**Solution**: Create independent clock running at tempo-based rate
**Impact**: Random source always shows activity
**Estimate**: 45 minutes

**Files**: `two_tangles.lua` init() and cleanup()

**Decision needed**: Update rate (recommend 1/8 note)

---

## UI Improvements (2-4 hours each)

Visual feedback and interface enhancements.

### 6. Redesign Pulse Animation
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium
**Details**: [PULSE_ANIMATION_REDESIGN.md](PULSE_ANIMATION_REDESIGN.md)

**Problems**:
- Sources don't pulse (except random)
- Register outputs pulse at full bright (override value)
- All stages pulse regardless of patching

**Solutions**:
- All sources pulse when clock runs
- Pulse at current brightness (multiplicative, not override)
- Register outputs only pulse when they have source patches

**Impact**: Clear visual feedback for clock state and patch activity
**Estimate**: 3 hours

**Files**: `two_tangles.lua` pulse animation system

---

### 7. Add Patch Visualization Page (Page 6)
**Priority**: 🔴 High
**Complexity**: 🟡 Medium
**Details**: [PATCH_VISUALIZATION_DESIGN.md](PATCH_VISUALIZATION_DESIGN.md)

**Problem**: No way to see all active patches with logic operators
**Solution**: New Page 6 with scrollable patch list
**Features**:
- Show all patches with source→destination
- Display logic operator and weight
- Scroll (E2), edit (K2), delete (K3)
- Quick navigation from ALT mode

**Impact**: Essential for understanding system state
**Estimate**: 4 hours

**Files**: `two_tangles.lua` new page functions

---

### 8. Improve Page 1 Patch Display
**Priority**: 🟡 Medium
**Complexity**: 🟢 Low
**Details**: [UI_IMPROVEMENTS_ANALYSIS.md](UI_IMPROVEMENTS_ANALYSIS.md)

**Problem**: Page 1 only shows "Patches: 5" count
**Solution**: Show 2-3 most recent patches with abbreviated info
**Impact**: Quick overview without switching pages
**Estimate**: 1 hour

**Files**: `two_tangles.lua` draw_main_page()

---

## Core Architecture Fixes (4-8 hours each)

These require design decisions and deeper changes to the audio engine.

### 9. Fix Shift Register Patching
**Priority**: 🔴 High
**Complexity**: 🔴 High
**Details**: [SHIFT_REGISTER_ANALYSIS.md](SHIFT_REGISTER_ANALYSIS.md)

**Problem**: Patches only work for stage 0, stages 1-7 just shift values
**Current behavior**: Only stage 0 calls `calculateStageInput()`
**Design decision needed**: Should patches override shifts at all stages?

**Options**:
- **A**: Patches override shifts (recommended)
- **B**: Patches modulate shifts
- **C**: Keep stage 0 only (document limitation)

**Impact**: Major change to how patterns evolve
**Estimate**: 6 hours (including testing)

**Files**: `lib/Engine_TwoTangles.sc` stepShiftRegister()

**Blockers**: Need design decision from user

---

### 10. Verify Cross-Register Patching
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium
**Details**: [SHIFT_REGISTER_ANALYSIS.md](SHIFT_REGISTER_ANALYSIS.md)

**Task**: Test and verify register A → register B patches work correctly
**Method**: Create test patch, monitor values
**Estimate**: 1 hour

**Note**: May reveal issues related to #9

---

### 11. Verify Stage-to-Stage Propagation
**Priority**: 🟡 Medium
**Complexity**: 🟢 Low
**Details**: [SHIFT_REGISTER_ANALYSIS.md](SHIFT_REGISTER_ANALYSIS.md)

**Task**: Verify values shift from stage N-1 to stage N correctly
**Method**: Monitor register values during stepping
**Estimate**: 30 minutes

**Expected**: This should already work correctly

---

## New Features (6-12 hours each)

New functionality additions.

### 12. Add Pitch Quantization
**Priority**: 🟢 Low
**Complexity**: 🟡 Medium
**Details**: [PITCH_QUANTIZATION_DESIGN.md](PITCH_QUANTIZATION_DESIGN.md)

**Feature**: Constrain pitch modulation to musical scales
**Implementation**:
- Per-voice quantization settings
- 13 scales (modes, pentatonic, blues, etc.)
- Root note transposition
- UI on Page 5

**Impact**: Musical control over pitch sequences
**Estimate**: 8 hours

**Files**:
- `lib/Engine_TwoTangles.sc` - Quantization system
- `two_tangles.lua` - Page 5 controls

---

## Recommended Implementation Order

### Phase 1: Quick Wins (1 week)
Focus on immediate user experience improvements with minimal risk.

1. ✅ **Source LED brightness fix** (30 min)
2. ✅ **Random source timing fix** (45 min)
3. ✅ **Pulse animation redesign** (3 hours)
4. ✅ **Page 1 display improvement** (1 hour)

**Total**: ~6 hours
**Impact**: Greatly improved visual feedback

### Phase 2: Patch Management (1 week)
Essential for understanding and debugging patches.

5. ✅ **Patch visualization page** (4 hours)
6. ✅ **Test cross-register patching** (1 hour)
7. ✅ **Test stage propagation** (30 min)

**Total**: ~6 hours
**Impact**: Full patch visibility and verification

### Phase 3: Architecture (2 weeks)
Core behavior fixes requiring design decisions.

8. ⚠️ **Decide shift register patch behavior** (discussion)
9. ✅ **Implement shift register patching** (6 hours)
10. ✅ **Test and document new behavior** (2 hours)

**Total**: ~8 hours + design discussion
**Impact**: Correct patch behavior at all stages

### Phase 4: New Features (2 weeks)
Polish and new capabilities.

11. ✅ **Pitch quantization** (8 hours)
12. ✅ **Documentation updates** (2 hours)
13. ✅ **User testing and refinement** (ongoing)

**Total**: ~10 hours
**Impact**: Musical pattern control

---

## Dependencies

```
Source LED Fix ────┐
Random Timing Fix ─┼─> Pulse Animation Redesign
                   │
Patch List Page ───┘

Stage Propagation Test ──┐
Cross-Register Test ─────┼─> Shift Register Fix
Design Decision ─────────┘

(All above) ──> Pitch Quantization
```

---

## Risk Assessment

### Low Risk ✅
- Source LED brightness fix
- Random source timing fix
- Page 1 display improvement
- Patch visualization page
- Verification tests

**Why**: UI-only changes, no audio engine impact

### Medium Risk ⚠️
- Pulse animation redesign

**Why**: Changes visual system, but well-documented

### High Risk 🔴
- Shift register patching fix

**Why**: Changes core audio engine behavior, needs careful testing

---

## Design Decisions Needed

### 1. Shift Register Patch Behavior
**Question**: Should patches work at all stages or just stage 0?
**Options**: Override shifts / Modulate shifts / Stage 0 only
**Blocker for**: Phase 3 implementation
**Recommendation**: Override shifts (Option A) for maximum flexibility

### 2. Random Source Update Rate
**Question**: How often should random source update?
**Options**: 1/4 note / 1/8 note / 1/16 note / Fixed 10Hz
**Blocker for**: Random timing fix
**Recommendation**: 1/8 note (good balance of activity and musicality)

### 3. Patch List Features
**Question**: Include filter/sort/copy features in initial version?
**Options**: Basic list only / Full featured
**Blocker for**: None (can add later)
**Recommendation**: Start basic, add features based on feedback

---

## Testing Strategy

### Unit Tests
- Source brightness with various values
- Random source updates at correct rate
- Pulse animation brightness calculations
- Patch list scroll and selection
- Shift register value propagation

### Integration Tests
- Multiple patches with sources
- Cross-register patches
- Patches with various logic operators
- Tempo changes affect random rate
- Clock stop/start maintains state

### User Acceptance Tests
- Create complex patch network
- Navigate and edit patches on Page 6
- Observe visual feedback during playback
- Verify audio matches visual state
- Save/recall patch presets

---

## Documentation Updates

After each phase, update:

1. **README.md**
   - Interface overview
   - Page descriptions
   - Feature explanations
   - Quick start examples

2. **Changelog**
   - Version numbers
   - Feature additions
   - Bug fixes
   - Breaking changes

3. **Analysis docs**
   - Mark items as completed
   - Document actual vs expected behavior
   - Note any deviations from plan

---

## Success Metrics

### Phase 1 Success
- [ ] Source LEDs always show correct brightness
- [ ] Random source animates when clock stopped
- [ ] All sources pulse when clock runs
- [ ] Register outputs pulse only when receiving source injections
- [ ] Page 1 shows recent patches

### Phase 2 Success
- [ ] Page 6 shows all patches with full details
- [ ] Can scroll through patches
- [ ] Can edit/delete patches from list
- [ ] Cross-register patches verified working
- [ ] Stage propagation verified working

### Phase 3 Success
- [ ] Patches work at all stages 0-7
- [ ] Behavior matches design decision
- [ ] All stages receive patched values correctly
- [ ] Documentation explains new behavior

### Phase 4 Success
- [ ] Pitch quantization works for all scales
- [ ] Root note transposition works
- [ ] UI controls are intuitive
- [ ] Musical results are pleasing

---

## Next Steps

1. **Review this roadmap** with user
2. **Get design decisions** on open questions
3. **Start Phase 1** with quick wins
4. **Iterate and test** each implementation
5. **Gather feedback** and adjust priorities

---

## Contact & Feedback

Document any issues, suggestions, or design questions as you go. Each feature has a detailed analysis document for reference.

**Current Status**: Phase 0 Complete (Analysis & Planning)
**Next Phase**: Phase 1 (Quick Wins)
**Estimated Timeline**: 6-8 weeks for all phases
