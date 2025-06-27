---
external help file: PSSnow-help.xml
Module Name: PSSnow
online version: docs/functions/Start-SNOWGlideAjaxUpdateSetPreview.md
schema: 2.0.0
---

# Start-SNOWGlideAjaxUpdateSetPreview

## SYNOPSIS
Starts a preview of an update set in ServiceNow.

## SYNTAX

```
Start-SNOWGlideAjaxUpdateSetPreview [-sys_id] <String> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This function uses GlideAjax to start a preview of an update set in ServiceNow.
It uses the UpdateSetPreviewAjax processor for single update sets and HierarchyUpdateSetPreviewAjax for batch update sets.

## EXAMPLES

### Example 1
```powershellpowershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -sys_id
The sys_id of the remote update set to be previewed.

```yaml
Type: System.String
Parameter Sets: (All)
Aliases: remote_update_set_id

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: System.Management.Automation.ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

Returns the raw GlideAjax response from the ServiceNow instance.
## NOTES

## RELATED LINKS

