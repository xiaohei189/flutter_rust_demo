$ErrorActionPreference = "Stop"

$rustRoot = Split-Path -Parent $PSScriptRoot

$typeGroups = @(
    @{ Module = "core::config"; File = "src/core/config.rs"; Names = @("ClientConfig") },
    @{
        Module = "core::event::events::connection"
        File = "src/core/event/events/connection.rs"
        Names = @("ConnectionEvent")
    },
    @{
        Module = "core::event::events::conversation"
        File = "src/core/event/events/conversation.rs"
        Names = @("ConversationEvent")
    },
    @{
        Module = "core::event::events::friend"
        File = "src/core/event/events/friend.rs"
        Names = @("FriendEvent")
    },
    @{
        Module = "core::event::events::group"
        File = "src/core/event/events/group.rs"
        Names = @("GroupEvent")
    },
    @{
        Module = "core::event::events::message"
        File = "src/core/event/events/message.rs"
        Names = @("GroupReadReceipt", "MessageEvent", "MessageReceipt")
    },
    @{
        Module = "core::event::events::user"
        File = "src/core/event/events/user.rs"
        Names = @("UserEvent")
    },
    @{
        Module = "domain::constant::enums"
        File = "src/domain/constant/enums.rs"
        Names = @("ConnectionState", "SessionType")
    },
    @{
        Module = "domain::model::friend"
        File = "src/domain/model/friend.rs"
        Names = @("FriendInfo")
    },
    @{
        Module = "domain::model::group"
        File = "src/domain/model/group.rs"
        Names = @("GroupInfo", "GroupMember")
    },
    @{
        Module = "domain::model::local"
        File = "src/domain/model/local.rs"
        Names = @("LocalChatLog", "LocalConversation")
    },
    @{
        Module = "domain::model::message"
        File = "src/domain/model/message.rs"
        Names = @("MessageInfo")
    },
    @{
        Module = "domain::model::msg_struct"
        File = "src/domain/model/msg_struct.rs"
        Names = @(
            "AdvancedTextElem",
            "AtInfo",
            "AtTextElem",
            "CardElem",
            "CustomElem",
            "FaceElem",
            "FileElem",
            "LocationElem",
            "MarkdownTextElem",
            "MergeElem",
            "MessageEntity",
            "MsgStruct",
            "OfflinePushInfo",
            "PictureBaseInfo",
            "PictureElem",
            "QuoteElem",
            "SoundElem",
            "TextElem",
            "VideoElem"
        )
    },
    @{
        Module = "domain::model::user"
        File = "src/domain/model/user.rs"
        Names = @("UserInfo")
    },
    @{
        Module = "infra::http::friend"
        File = "src/infra/http/friend.rs"
        Names = @("CheckFriendResult", "FriendApplyInfo", "SearchFriendItem")
    },
    @{
        Module = "infra::http::group"
        File = "src/infra/http/group.rs"
        Names = @("GroupApplyInfo")
    },
    @{
        Module = "infra::http::message"
        File = "src/infra/http/message.rs"
        Names = @("DeleteMessagesReq", "MarkMessagesAsReadReq", "RevokeMessageReq")
    },
    @{
        Module = "infra::http::online"
        File = "src/infra/http/online.rs"
        Names = @("OnlineStatus")
    },
    @{
        Module = "infra::logger::config"
        File = "src/infra/logger/config.rs"
        Names = @("LogConfig")
    },
    @{
        Module = "sdk::client"
        File = "src/sdk/client/mod.rs"
        Names = @("GetHistoryMessagesReq", "GetHistoryMessagesResult", "SearchMessagesReq")
    }
)

function Get-TypeDefinition([string]$Text, [string]$Name) {
    $escapedName = [regex]::Escape($Name)
    $match = [regex]::Match($Text, "(?m)^pub\s+(?:struct|enum)\s+$escapedName\b")
    if (-not $match.Success) {
        throw "Type '$Name' was not found."
    }

    $braceStart = $Text.IndexOf("{", $match.Index)
    if ($braceStart -lt 0) {
        throw "Type '$Name' has no braced body."
    }

    $depth = 0
    $braceEnd = -1
    for ($i = $braceStart; $i -lt $Text.Length; $i++) {
        switch ($Text[$i]) {
            "{" { $depth++ }
            "}" {
                $depth--
                if ($depth -eq 0) {
                    $braceEnd = $i
                    break
                }
            }
        }
        if ($braceEnd -ge 0) {
            break
        }
    }

    if ($braceEnd -lt 0) {
        throw "Type '$Name' has an unterminated body."
    }

    $definition = $Text.Substring($match.Index, $braceEnd - $match.Index + 1)
    $definition = [regex]::Replace(
        $definition,
        "^pub\s+(struct|enum)\s+$escapedName\b",
        "pub `$1 _$Name",
        1
    )

    # FRB only needs the type shape. Derive-only attributes are invalid on a
    # mirror placeholder unless all derives are repeated, so omit them.
    $definition = ($definition -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#\[' }) -join "`n"
    $definition = [regex]::Replace(
        $definition,
        "(?m)^pub\s+(struct|enum)\s+_$escapedName\b",
        "/// flutter_rust_bridge:mirror($Name)`n/// flutter_rust_bridge:unignore`n/// flutter_rust_bridge:non_opaque`n#[allow(dead_code)]`npub `$1 _$Name"
    )
    return $definition
}

function Write-GeneratedFile([string]$RelativePath, [string[]]$Lines) {
    $output = Join-Path $rustRoot $RelativePath
    $directory = Split-Path -Parent $output
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $header = @(
        "// The dependency imports are intentionally broad for FRB's type resolver.",
        "#![allow(unused_imports)]",
        "//! FRB compatibility module generated by rust/scripts/generate-frb-mirrors.ps1.",
        "//! Do not edit.",
        ""
    )
    [System.IO.File]::WriteAllText(
        $output,
        (($header + $Lines) -join "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
}

$children = [ordered]@{
    "core" = @("config", "event")
    "core::event" = @("events")
    "core::event::events" = @("connection", "conversation", "friend", "group", "message", "user")
    "domain" = @("constant", "model")
    "domain::constant" = @("enums")
    "domain::model" = @("friend", "group", "local", "message", "msg_struct", "user")
    "infra" = @("http", "logger")
    "infra::http" = @("friend", "group", "message", "online")
    "infra::logger" = @("config")
    "sdk" = @("client")
}

foreach ($entry in $children.GetEnumerator()) {
    $lines = @("pub use im_core::$($entry.Key)::*;")
    $lines += @($entry.Value | ForEach-Object { "pub mod $_;" })
    $relative = "src/" + (($entry.Key -replace "::", "/") + "/mod.rs")
    Write-GeneratedFile $relative $lines
}

foreach ($group in $typeGroups) {
    $sourcePath = Join-Path (Join-Path $rustRoot "im-core") $group.File
    $source = Get-Content -Raw -Encoding UTF8 $sourcePath
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("pub use im_core::$($group.Module)::*;")
    $lines.Add("")
    foreach ($name in $group.Names) {
        $definition = Get-TypeDefinition $source $name
        $dependencyNames = [regex]::Matches($definition, '\b[A-Z][A-Za-z0-9_]*\b') |
            ForEach-Object { $_.Value } |
            Sort-Object -Unique |
            Where-Object { $_ -notin $group.Names }
        foreach ($dependencyName in $dependencyNames) {
            $dependencyGroup = $typeGroups | Where-Object { $dependencyName -in $_.Names } | Select-Object -First 1
            if ($dependencyGroup -and $dependencyGroup.Module -ne $group.Module) {
                $lines.Add("use crate::$($dependencyGroup.Module)::$dependencyName;")
            }
        }
        if ($dependencyNames.Count -gt 0) {
            $lines.Add("")
        }
        $lines.Add($definition)
        $lines.Add("")
        if ($name -ne "PictureElem") {
            $anchorName = "frb_mirror_anchor_" + ($name -creplace '([a-z0-9])([A-Z])', '$1_$2').ToLowerInvariant()
            $lines.Add("pub fn $anchorName(value: $Name) {")
            $lines.Add("    let _ = value;")
            $lines.Add("}")
            $lines.Add("")
        }
    }
    $relative = "src/" + (($group.Module -replace "::", "/") + ".rs")
    Write-GeneratedFile $relative $lines
}

Write-Host "Generated FRB compatibility modules under $rustRoot/src"
