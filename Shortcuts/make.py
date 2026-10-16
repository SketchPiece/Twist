"""Builds the Twist On / Twist Off shortcuts. Sign with sign.sh afterwards."""
import plistlib

ADJ = "6F1A8E52-3C1B-4B8E-9E0D-2B7A5C3D9A10"
QUESTION = [{
    "ActionIndex": 0, "Category": "Parameter", "ParameterKey": "FocusModes",
    "Text": "Which Focus is Twist's?",
}]

def shortcut(actions, questions, takes_input):
    return {
        "WFWorkflowClientVersion": "2607.0.2",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4282601983, "WFWorkflowIconGlyphNumber": 59511},
        "WFWorkflowTypes": [],
        "WFWorkflowInputContentItemClasses": ["WFStringContentItem"] if takes_input else [],
        "WFWorkflowHasShortcutInputVariables": takes_input,
        "WFWorkflowImportQuestions": questions,
        "WFWorkflowActions": actions,
    }

def set_focus(on, until=None):
    p = {"Enabled": 1 if on else 0}
    if until:
        p["AssertionType"] = "Time"
        p["Time"] = until
    return {"WFWorkflowActionIdentifier": "is.workflow.actions.dnd.set", "WFWorkflowActionParameters": p}

adjust = {
    "WFWorkflowActionIdentifier": "is.workflow.actions.adjustdate",
    "WFWorkflowActionParameters": {
        "UUID": ADJ,
        "WFAdjustOperation": "Add",
        "WFDate": {"Value": {"attachmentsByRange": {"{0, 1}": {"Type": "CurrentDate"}}, "string": "￼"},
                   "WFSerializationType": "WFTextTokenString"},
        "WFDuration": {"Value": {"Magnitude": {"Value": {"Type": "ExtensionInput"},
                                               "WFSerializationType": "WFTextTokenAttachment"},
                                 "Unit": "min"},
                       "WFSerializationType": "WFQuantityFieldValue"},
    },
}
until = {"Value": {"OutputUUID": ADJ, "Type": "ActionOutput", "OutputName": "Adjusted Date"},
         "WFSerializationType": "WFTextTokenAttachment"}

on = shortcut([adjust, set_focus(True, until)], [dict(QUESTION[0], ActionIndex=1)], True)
off = shortcut([set_focus(False)], QUESTION, False)
for name, s in (("Twist On", on), ("Twist Off", off)):
    with open(f"build/{name}.unsigned.shortcut", "wb") as f:
        plistlib.dump(s, f, fmt=plistlib.FMT_BINARY)
