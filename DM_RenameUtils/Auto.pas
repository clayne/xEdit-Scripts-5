unit Auto;
uses xEditApi, 'DM_RenameUtils\AutoSpell',
'DM_RenameUtils\AutoBook', 'DM_RenameUtils\AutoWeapon';

const
    iHOverride = $FFFF;     // Maximum record override to search for. This is way bigger than the maximum SSE supports.
    sNameValSep = '=';
    tagName = '[Name]';
    tagOriginalName = '[OriginalName]';
    tagSpellOriginalName = '[SpellOriginalName]';
    tagSpellName = '[SpellName]';
    tagSpell = '[Spell]';
    tagEdid = '[EDID]';

// Creates a string in the form 'Name=Value'
function FmtNameValue(aName, aValue: string): string;
begin
    Result := AName + sNameValSep + aValue;
end;

procedure AddTag(aData: TStringList; aTag, aValue: string);
begin
    aData.Add(FmtNameValue(aTag, aValue));
end;

// Gets the name of the item as defined in the first esp that creates it
function GetOriginalName(e: IInterface): string;
begin
    e := MasterOrSelf(e);
    Result := GetElementEditValues(e, 'FULL');
end;

// Adds the tags '[OriginalName]=Name' and '[Name]=Name' to a tag list
procedure AddName(aList: TStringList; e: IInterface);
begin
    AddTag(aList, tagOriginalName, GetOriginalName(e));
    AddTag(aList, tagName, GetElementEditValues(e, 'FULL'));
end;

// Adds the tag '[EDID]=Id' to a tag list
procedure AddEdid(aList: TStringList; e: IInterface);
begin
    AddTag(aList, tagEdid, GetElementEditValues(e, 'EDID'));
end;

// Logs an unnamed record
procedure _LogUnnamed(aData: TStringList);
var
    edid: string;
begin
    edid := ValueFromName(aData, tagEdid);
    AddMessage(
        Format('[%s] is an unnamed record. Skipping renaming.', [edid])
    );
end;

// Logs info for a format not found
procedure _LogNoFormat(aFmtName, aName: string);
const
    e1 = '***ERROR*** %s couldn''t be renamed because no format was found.';
    e2 = 'If file "_Formats.ini" exists and has a line called "%s=Whatever you want your record to be named", then this is a programmer error.';
begin
    AddMessage( Format(e1 + #13#10 + e2, [aName, aFmtName]) );
end;

// Generates a name from a set of tags using it's required format.
// This format is defined in _Formats.ini
function GenerateName(recType: string; aData: TStringList): string;
var
    i: Integer;
    originalName, fmt: string;
begin
    originalName := ValueFromName(aData, '[OriginalName]');

    // Probably not "optimum" to do this check so late, but quite convenient
    // to do it here, since I won't forget to check it everywhere.
    if originalName = '' then begin
        _LogUnnamed(aData);
        Result := '';
        Exit;
    end;

    // cfgFormats is defined in Globals
    fmt := ValueFromName(cfgFormats, recType);
    if fmt = '' then begin
        _LogNoFormat(recType, originalName);
        Result := originalName;
        Exit;
    end;

    LogExtDebug('Template format defined by you:'+ nl + fmt);

    // Actual replacing
    Result := fmt;
    for i := 0 to aData.Count - 1 do begin
        Result := StringReplace(
            Result,
            aData.Names[i],
            Value(aData, i),
            [rfReplaceAll]
        );
    end;

    LogExtDebug(nl + 'End result:'+ nl + Result + nl);
end;

// Substitutes tags found for some record to the names the user actually wants.
// Names are defined in _Names.ini
function ReplaceTags(aList: TStringList): TStringList;
var
    i: Integer;
    s, name, val: string;
    cfg: TStringList;
begin
    cfg := cfgNames;
    Result := CreateSortedList;

    try
        LogExtDebug(nl + '*** Raw tags found ***'+ nl + aList.Text);
        for i := 0 to aList.Count - 1 do begin
            name := Value(aList, i);
            val := ValueFromName(cfg, Value(aList, i));
            // Had to do this because this stupid bullshit can't directly assign values to aList[i]
            if val <> '' then
                Result.Add(aList.Names[i] + sNameValSep + val)
            else
                Result.Add(aList[i]);
        end;
        LogExtDebug('*** Translated tags ***'+ nl + Result.Text);
    finally
        aList.Free;
    end;
end;

// Does the actual renaming based on the record type
function GetAutoName(e: IInterface): string;
var
    sig: string;
begin
    sig := Signature(e);
    if sig = 'SPEL' then
        Result := GetSpellName(e)
    else if sig = 'BOOK' then
        Result := GetBookName(e)
    else if sig = 'WEAP' then
        Result := GetWeaponName(e)
    else begin
        Result := GetElementEditValues(e, 'FULL');
        AddMessage(sig + ' auto renaming still not supported');
    end;
end;

procedure ReplaceTagName(aTags: TStringList; aOldTag, aNewTag: string);
var
    val: string;
begin
    val := ValueFromName(aTags, aOldTag);
    aTags.Delete(aTags.IndexOfName(aOldTag));
    aTags.Add( FmtNameValue(aNewTag, val) );
end;

end.
