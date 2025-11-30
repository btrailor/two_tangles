# Two Tangles - Analysis Documents Index

This index provides quick access to all analysis and design documents created for the Two Tangles improvement project.

## Quick Navigation

| Document | Topic | Status | Priority |
|----------|-------|--------|----------|
| [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md) | **Master Plan** | 📋 Planning | - |
| [K1_HOLD_FIX.md](K1_HOLD_FIX.md) | K1 Hold Modifier | ✅ Complete | - |
| [SOURCE_RELOCATION_CHANGES.md](SOURCE_RELOCATION_CHANGES.md) | 3×3 Source Grid | ✅ Complete | - |
| [SOURCE_LED_BRIGHTNESS_FIX.md](SOURCE_LED_BRIGHTNESS_FIX.md) | Source LED Brightness | 📝 Ready | 🔴 High |
| [RANDOM_SOURCE_TIMING_FIX.md](RANDOM_SOURCE_TIMING_FIX.md) | Random Animation | 📝 Ready | 🟡 Medium |
| [PULSE_ANIMATION_REDESIGN.md](PULSE_ANIMATION_REDESIGN.md) | Pulse System | 📝 Ready | 🟡 Medium |
| [PATCH_VISUALIZATION_DESIGN.md](PATCH_VISUALIZATION_DESIGN.md) | Patch List Page | 📝 Ready | 🔴 High |
| [UI_IMPROVEMENTS_ANALYSIS.md](UI_IMPROVEMENTS_ANALYSIS.md) | General UI Issues | 📝 Ready | 🟡 Medium |
| [SHIFT_REGISTER_ANALYSIS.md](SHIFT_REGISTER_ANALYSIS.md) | Patch Behavior | ⚠️ Needs Decision | 🔴 High |
| [PITCH_QUANTIZATION_DESIGN.md](PITCH_QUANTIZATION_DESIGN.md) | Scale Quantization | 📝 Ready | 🟢 Low |

---

## By Category

### ✅ Completed Implementations

#### K1 Hold Fix
**File**: [K1_HOLD_FIX.md](K1_HOLD_FIX.md)
**Summary**: Removed clock start/stop from K1 so hold modifier works for encoders
**Changes**: `two_tangles.lua` lines 1849-1856, `README.md` line 138

#### Source Relocation
**File**: [SOURCE_RELOCATION_CHANGES.md](SOURCE_RELOCATION_CHANGES.md)
**Summary**: Moved sources to 3×3 grid with value-based brightness
**Changes**: `two_tangles.lua` multiple sections

---

### 🎨 UI/Visual Improvements

#### Source LED Brightness Fix
**File**: [SOURCE_LED_BRIGHTNESS_FIX.md](SOURCE_LED_BRIGHTNESS_FIX.md)
**Problem**: Source LEDs show patch weight instead of source value
**Solution**: Conditional check to use source value for source patches
**Complexity**: 🟢 Low
**Estimate**: 30 minutes
**Files**: `two_tangles.lua` line ~2260

#### Random Source Timing Fix
**File**: [RANDOM_SOURCE_TIMING_FIX.md](RANDOM_SOURCE_TIMING_FIX.md)
**Problem**: Random source only animates when clock runs
**Solution**: Independent clock at tempo-based rate
**Complexity**: 🟢 Low
**Estimate**: 45 minutes
**Decision Needed**: Update rate (recommend 1/8 note)
**Files**: `two_tangles.lua` init() and cleanup()

#### Pulse Animation Redesign
**File**: [PULSE_ANIMATION_REDESIGN.md](PULSE_ANIMATION_REDESIGN.md)
**Problems**:
- Only random source pulses
- Register outputs pulse at full bright
- All stages pulse regardless of patching

**Solutions**:
- All sources pulse when clock runs
- Pulse at current brightness (multiplicative)
- Register outputs only pulse with source patches

**Complexity**: 🟡 Medium
**Estimate**: 3 hours
**Files**: `two_tangles.lua` pulse system

#### Patch Visualization Page
**File**: [PATCH_VISUALIZATION_DESIGN.md](PATCH_VISUALIZATION_DESIGN.md)
**Problem**: No way to see all patches with logic operators
**Solution**: New Page 6 with scrollable list, edit/delete functions
**Features**:
- Show all patches (source→dest, logic, weight)
- Scroll, select, edit, delete
- Abbreviated logic names for space

**Complexity**: 🟡 Medium
**Estimate**: 4 hours
**Files**: `two_tangles.lua` new page

#### General UI Improvements
**File**: [UI_IMPROVEMENTS_ANALYSIS.md](UI_IMPROVEMENTS_ANALYSIS.md)
**Summary**: Umbrella document analyzing all UI issues
**Topics**:
- Patch visualization options
- Source LED brightness
- Random source timing
- Page 1 improvements

---

### 🔧 Core Architecture

#### Shift Register Analysis
**File**: [SHIFT_REGISTER_ANALYSIS.md](SHIFT_REGISTER_ANALYSIS.md)
**Problems Identified**:
- ✅ Stage-to-stage shifts work correctly
- ❌ Patches only affect stage 0
- ❌ Stages 1-7 ignore patches completely
- ❓ Design unclear: should patches work at all stages?

**Design Options**:
- **A**: Patches override shifts (recommended)
- **B**: Patches modulate shifts
- **C**: Stage 0 only (current, document limitation)

**Complexity**: 🔴 High
**Estimate**: 6 hours
**Status**: ⚠️ Awaiting design decision
**Files**: `lib/Engine_TwoTangles.sc` stepShiftRegister()

**Testing Scenarios**:
- Cross-register patches (B[2] → A[5])
- Source patches to non-zero stages (random → A[3])
- Multiple stages with patches
- Voice modulation impact

---

### 🎵 New Features

#### Pitch Quantization
**File**: [PITCH_QUANTIZATION_DESIGN.md](PITCH_QUANTIZATION_DESIGN.md)
**Feature**: Constrain pitch to musical scales
**Scales Included**:
- 7 modes (Ionian, Dorian, Phrygian, Lydian, Mixolydian, Aeolian, Locrian)
- Pentatonic (major/minor)
- Blues, Harmonic Minor, Whole Tone
- Chromatic (off)

**Implementation**:
- Per-voice quantization
- Root note transposition
- Page 5 UI controls (E2: scale, E3: root)
- SuperCollider quantization function

**Complexity**: 🟡 Medium
**Estimate**: 8 hours
**Files**: `lib/Engine_TwoTangles.sc`, `two_tangles.lua`

---

## Decision Matrix

### Decisions Made ✅

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Source layout | 3×3 grid | Visual grouping, brightness feedback |
| K1 behavior | Hold modifier only | Grid handles clock control |
| Patch page | New Page 6 | Dedicated space for full details |

### Decisions Needed ⚠️

| Decision | Options | Impact | Blocker For |
|----------|---------|--------|-------------|
| Shift register patches | Override / Modulate / Stage 0 | Core behavior | Architecture fixes |
| Random update rate | 1/4 / 1/8 / 1/16 / Fixed | User experience | Random timing fix |
| Patch list features | Basic / Full-featured | Development time | Initial release |

---

## Implementation Phases

### Phase 1: Quick Wins (Week 1)
- Source LED brightness fix
- Random source timing fix
- Pulse animation redesign
- Page 1 display improvement

**Total**: ~6 hours
**Risk**: Low
**Dependencies**: None

### Phase 2: Patch Management (Week 2)
- Patch visualization page
- Cross-register testing
- Stage propagation testing

**Total**: ~6 hours
**Risk**: Low
**Dependencies**: None

### Phase 3: Architecture (Weeks 3-4)
- Design decision on shift register behavior
- Implement shift register patching
- Testing and documentation

**Total**: ~8 hours
**Risk**: High
**Dependencies**: Design decision

### Phase 4: New Features (Weeks 5-6)
- Pitch quantization
- Documentation updates
- User testing

**Total**: ~10 hours
**Risk**: Low
**Dependencies**: All above complete

---

## Code Locations Reference

### Key Files

**Lua Script**: `two_tangles.lua`
- Lines 1-200: Constants and initialization
- Lines 800-1200: Grid interaction
- Lines 1600-1700: Patching logic
- Lines 2100-2350: Grid drawing
- Lines 2350-2800: Screen drawing
- Lines 1900-2100: Encoder/key handlers

**SuperCollider Engine**: `lib/Engine_TwoTangles.sc`
- Lines 1-100: Class definition and variables
- Lines 400-600: Clock and stepping
- Lines 661-731: stepShiftRegister (CRITICAL)
- Lines 733-810: calculateStageInput (CRITICAL)
- Lines 813-1050: Voice modulation
- Lines 1200-1400: OSC commands

**Documentation**: `README.md`
- Lines 1-50: Overview
- Lines 117-250: Interface guide
- Lines 250-400: Features explanation
- Lines 590+: Changelog

---

## Testing Checklist

### Visual Feedback Tests
- [ ] Source LEDs show correct brightness
- [ ] Random source animates continuously
- [ ] All sources pulse when clock runs
- [ ] Register outputs pulse only with source patches
- [ ] Pulse brightness matches LED value

### Patch Management Tests
- [ ] Page 6 shows all patches
- [ ] Can scroll through patch list
- [ ] Can edit patch from list
- [ ] Can delete patch from list
- [ ] Patch count is accurate

### Audio Behavior Tests
- [ ] Patches affect audio correctly
- [ ] Cross-register patches work
- [ ] Stage propagation is correct
- [ ] Voice modulation reads correct values
- [ ] Quantization constrains pitch

### Integration Tests
- [ ] Tempo changes affect random rate
- [ ] Clock stop/start maintains state
- [ ] Multiple patches don't conflict
- [ ] Save/recall preserves patches
- [ ] Grid and screen stay synchronized

---

## Troubleshooting Guide

### Common Issues

**Source LEDs showing wrong brightness**
- Check: Line 2260 in two_tangles.lua
- Should use source value, not patch weight
- See: SOURCE_LED_BRIGHTNESS_FIX.md

**Random source not animating**
- Check: Random source clock is running
- Check: Clock is being cancelled in cleanup()
- See: RANDOM_SOURCE_TIMING_FIX.md

**Patches not working at stage 3+**
- Expected: Only stage 0 patches work currently
- Check: SHIFT_REGISTER_ANALYSIS.md for explanation
- Solution: Awaiting design decision + implementation

**Pulse animation looks wrong**
- Check: Pulse system using multiplicative, not override
- Check: has_source_patch() function working
- See: PULSE_ANIMATION_REDESIGN.md

---

## Contributing

When implementing any feature:

1. **Read the analysis doc** fully before starting
2. **Follow the implementation checklist** in the doc
3. **Test all scenarios** listed in the doc
4. **Update the doc** with actual results vs expected
5. **Mark todo as complete** when finished
6. **Update IMPLEMENTATION_ROADMAP.md** status

---

## Document Status Legend

- ✅ **Complete**: Implementation finished and tested
- 📝 **Ready**: Analysis complete, ready to implement
- ⚠️ **Needs Decision**: Blocked by design decision
- 📋 **Planning**: High-level overview/coordination
- 🔴 **High Priority**: Important for core functionality
- 🟡 **Medium Priority**: Improves user experience
- 🟢 **Low Priority**: Nice-to-have feature

---

## Version History

**v1.0** - Initial analysis documents created
- Comprehensive analysis of all requested features
- Design documents with multiple options
- Implementation roadmap with phases
- Testing strategies and checklists

**Current Version**: v1.0
**Last Updated**: 2025-10-29
**Documents**: 11 total (10 analysis + 1 roadmap)

---

## Quick Start Guide

### For Implementers

1. Start here: [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)
2. Read Phase 1 documents in order
3. Implement, test, document
4. Move to next phase

### For Reviewers

1. Check [SHIFT_REGISTER_ANALYSIS.md](SHIFT_REGISTER_ANALYSIS.md) for critical design decision
2. Review Phase 1 "Quick Wins" for immediate improvements
3. Provide feedback on proposed solutions

### For Users

1. See [K1_HOLD_FIX.md](K1_HOLD_FIX.md) for latest behavior changes
2. Check [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md) for upcoming features
3. Review [PATCH_VISUALIZATION_DESIGN.md](PATCH_VISUALIZATION_DESIGN.md) for new Page 6

---

**Total Analysis**: 11 documents, ~8000 lines of detailed specifications
**Ready to Implement**: 9 features with complete plans
**Awaiting Decisions**: 1 feature (shift register behavior)
