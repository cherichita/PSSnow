---
external help file: PSSnow-help.xml
Module Name: PSSnow
online version: docs/functions/Start-SNOWGlideAjaxUpdateSetCommit.md
schema: 2.0.0
---

# Start-SNOWGlideAjaxUpdateSetCommit

## SYNOPSIS
Starts the commit process for a ServiceNow update set.

## SYNTAX

```
Start-SNOWGlideAjaxUpdateSetCommit [-sys_id] <String> [-ForceCommit] [[-AcceptDataLoss] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function starts the commit process for a ServiceNow update set using the GlideAjax API and WebSessions.
It uses the following sysparm_processors:
- UpdateSetCommitAjaxProcessor for validating the update set before committing it.
- com.glide.update.UpdateSetCommitAjaxProcessor for single update sets.
- HierarchyUpdateSetCommitAjax for batch update sets.
The function validates the update set before committing it and can handle data loss scenarios if specified.

## EXAMPLES

### EXAMPLE 1
```powershell
Start-SNOWGlideAjaxUpdateSetCommit -sys_id "1234567890abcdef"
```

Starts the commit process for the specified update set and returns the result.

### EXAMPLE 2
```powershell
Start-SNOWGlideAjaxUpdateSetCommit -sys_id "1234567890abcdef" | Wait-SNOWCICDProgress
```

Starts the commit process and waits for it to complete by piping the result to Wait-SNOWCICDProgress.

### EXAMPLE 3
```powershell
Get-SNOWUpdateSet -sys_id "1234567890abcdef" | Start-SNOWGlideAjaxUpdateSetCommit | Wait-SNOWCICDProgress
```

Gets the update set, starts the commit process, and waits for it to complete.

### EXAMPLE 4
```powershell
Start-SNOWGlideAjaxUpdateSetCommit -sys_id "1234567890abcdef" -ForceCommit
```

Forces the commit process for the specified update set, bypassing validation checks.

### EXAMPLE 5
```powershell
Start-SNOWGlideAjaxUpdateSetCommit -sys_id "1234567890abcdef" -AcceptDataLoss "Dictionary:sys_dictionary_sn_si_incident_u_impacted_user_s,Dictionary:sys_dictionary_sn_si_incident_u_no_of_mission_critical_assets"
```

Starts the commit process for the specified update set and accepts data loss for the specified fields.

## PARAMETERS

### -sys_id
The sys_id of the remote update set to be committed.

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

### -ForceCommit
Switch that indicates whether to force commit the update set.
Force commits the update set even if you haven't yet previewed it to check for conflicts.

Default: Doesn't force commit the update set.
You must preview the update set before proceeding with the commit.

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -AcceptDataLoss
Accepts data loss during commit Example: Dictionary:sys_dictionary_sn_si_incident_u_impacted_user_s,Dictionary:sys_dictionary_sn_si_incident_u_no_of_mission_critical_assets

```yaml
Type: System.String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
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

## NOTES

## RELATED LINKS

