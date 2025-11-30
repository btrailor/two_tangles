# Shift Register Behavior Analysis

## Current Implementation Issues

### Problem 1: Patches Only Affect Stage 0

**Location**: `Engine_TwoTangles.sc` lines 686-693

The `stepShiftRegister` method only calls `calculateStageInput` for stage 0:

```supercollider
// Shift existing values (stages 1-7)
(activeLength - 1).do { arg i;
    if(1.0.rand < prob[activeLength - 1 - i], {
        reg[activeLength - 1 - i] = reg[activeLength - 2 - i];  // Direct copy
        activeStages[activeLength - 1 - i] = 1;
    });
};

// Only stage 0 uses patches
newValue = this.calculateStageInput(which, 0);  // Only called for stage 0!
```

**Result**:
- ✅ Stage 0 patches work correctly (sources, cross-register, feedback)
- ❌ Stages 1-7 ignore patches completely
- ❌ If you patch "random source → A[3]", it has **no effect**
- ❌ If you patch "B[2] → A[5]", it has **no effect**

### Problem 2: Stage Values Just Shift

Stages 1-7 use **direct value copying**:
```
Stage 7 ← Stage 6
Stage 6 ← Stage 5
Stage 5 ← Stage 4
...
Stage 1 ← Stage 0
```

This is like a traditional shift register, BUT it **ignores the patch matrix** except for stage 0.

## Expected Behavior (Design Question)

### Option A: Patches Should Override Shifts

If a stage has a patch, it should **replace** the shifted value with the patched value:

```supercollider
// For each stage
activeLength.do { arg i;
    var newValue;

    // Check if this stage has patches
    newValue = this.calculateStageInput(which, i);

    // If calculateStageInput found patches, use them
    // If not, shift from previous stage
    if(1.0.rand < prob[i], {
        reg[i] = newValue;
        activeStages[i] = 1;
    });
};
```

**Behavior**:
- Stage with patch: Uses patched value (ignores shift)
- Stage without patch: Shifts from previous stage
- Allows "breaking" the shift register flow with external injections

### Option B: Patches Should Modulate Shifts

Patches **combine with** shifted values using logic operators:

```supercollider
activeLength.do { arg i;
    var shiftedValue, patchValue, finalValue;

    // Get shifted value from previous stage
    shiftedValue = if(i == 0, {
        reg[activeLength - 1];  // Wrap from last stage
    }, {
        reg[i - 1];  // Previous stage
    });

    // Get patched value (if any)
    patchValue = this.calculateStageInput(which, i);

    // Combine using patches' logic operators
    // (This would require passing shifted value to calculateStageInput)
    finalValue = patchValue;  // Or apply logic op to shiftedValue

    if(1.0.rand < prob[i], {
        reg[i] = finalValue;
        activeStages[i] = 1;
    });
};
```

**Behavior**:
- Values flow through shift register
- Patches can modify flowing values using logic ops
- More complex modulation possibilities

### Option C: Current Behavior Is Intentional

Only stage 0 should accept patches, and the rest naturally shift:

```
[Input Stage] → [Stage 1] → [Stage 2] → ... → [Stage 7]
     ↑
  Patches
```

**Rationale**:
- Simple, predictable
- Patches seed the pattern at stage 0
- Pattern evolves through shift register
- Cross-register and source patches still work (at stage 0)

## Recommendations

### Short Term: Document Current Behavior

Update UI to show that **patches only affect stage 0**:
- Row 2 (stage 0 + 1) is the only "input" row
- Rows 3-8 are "output only" (display shifted values)
- Update README to clarify this limitation

### Medium Term: Implement Option A

Allow patches to override shifts at any stage:
```supercollider
stepShiftRegister { arg which;
    // ... existing setup ...

    activeLength.do { arg i;
        var newValue;

        // Try to get patched value
        newValue = this.calculateStageInput(which, i);

        // Apply probability
        if(1.0.rand < prob[i], {
            reg[i] = newValue;
            activeStages[i] = 1;
        });
    };

    // ... rest of method ...
}
```

**Changes needed**:
1. Modify `stepShiftRegister` to call `calculateStageInput` for all stages
2. Modify `calculateStageInput` to fall back to shifted value if no patches exist
3. Update unpatched behavior to shift from previous stage

### Long Term: Add Patch Mode Parameter

Add a parameter to choose behavior per-patch:
- **Replace**: Patch overrides shift (Option A)
- **Modulate**: Patch modifies shifted value (Option B)
- **Stage 0 Only**: Current behavior (Option C)

## Testing Scenarios

### Test 1: Cross-Register Patch to Stage 3
```
Patch: B[2] → A[3] (weight 1.0, logic REPLACE)
Expected (Option A): A[3] should match B[2] value
Current: A[3] shifts from A[2], ignores B[2]
```

### Test 2: Source Patch to Stage 5
```
Patch: random → A[5]
Expected (Option A): A[5] should be random on each step
Current: A[5] shifts from A[4], ignores random source
```

### Test 3: Multiple Stages with Patches
```
Patch: random → A[0]
Patch: max → A[3]
Patch: B[1] → A[6]
Expected (Option A):
  - A[0] = random
  - A[1] = A[0] shifted
  - A[2] = A[1] shifted
  - A[3] = 1.0 (max source)
  - A[4] = A[3] shifted
  - A[5] = A[4] shifted
  - A[6] = B[1] value
  - A[7] = A[6] shifted
Current: Only A[0] respects random patch, rest just shift
```

## Voice Modulation Impact

**Good news**: Voice modulation is working correctly!

Lines 842-847 in `updateVoice`:
```supercollider
srcValue = if(stageOutputs[srcReg].notNil && (srcStage < stageOutputs[srcReg].size), {
    stageOutputs[srcReg][srcStage];
}, {
    0.0;
});
```

This reads from `stageOutputs` which is updated with register values after shifting (line 683). So voices correctly read from any register stage, regardless of patch issues.

**The problem is**: If you expect patches to inject values at stages 1-7, those values won't be there. The voice will modulate with shifted values, not patched values.

## Summary

1. ✅ **Voice modulation works** - reads register stages correctly
2. ❌ **Patches only work for stage 0** - stages 1-7 ignore patches
3. ❓ **Design decision needed**: Should patches affect all stages or just stage 0?

My recommendation: **Implement Option A** (patches override shifts) as it provides maximum flexibility and matches user expectations based on the UI design.
