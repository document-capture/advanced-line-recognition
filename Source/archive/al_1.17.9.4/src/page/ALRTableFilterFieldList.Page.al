page 61000 "ALR Table Filter Field List"
{
    // C/SIDE
    // revision:11

    Caption = 'Table Filters';
    DeleteAllowed = false;
    InsertAllowed = false;
    LinksAllowed = false;
    PageType = List;
    SourceTable = "Field";
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Caption = 'No.';
                    Editable = false;
                    ToolTip = 'Specifies the number of the field in the source table to apply a filter.';
                }
                field("Field Caption"; Rec."Field Caption")
                {
                    ApplicationArea = All;
                    Caption = 'Caption';
                    Editable = false;
                    ToolTip = 'Specifies the caption of the field.';
                }
                field(FilterTypeColumn; FilterType)
                {
                    ApplicationArea = All;
                    Caption = 'Filter Type';
                    OptionCaption = 'Fixed Filter,Document Field';
                    ToolTip = 'Specifies whether the filter is either a fixed filter or if the filter value should be taken from another field.';
                    Visible = ShowType;
                }
                field(Value; Value)
                {
                    ApplicationArea = All;
                    Caption = 'Filter';
                    ToolTip = 'Specifies the filter to apply to the field.';

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        EXIT(LookupValue(Text));
                    end;

                    trigger OnValidate()
                    begin
                        SetValue(Value);
                        CurrPage.UPDATE(FALSE);
                    end;
                }
            }
        }
    }

    actions
    {
    }

    trigger OnAfterGetRecord()
    var
        CDCTableFilterField: Record "CDC Table Filter Field";
    begin
        CDCTableFilterField.SETRANGE("Table Filter GUID", TableGUID);
        CDCTableFilterField.SETRANGE("Field No.", Rec."No.");
        IF NOT CDCTableFilterField.FindFirst() THEN
            CLEAR(CDCTableFilterField);
        CDCTableFilterField.GetValues(Value, FilterType);
    end;

    var
        PrimaryKeyOnlyOneFieldLbl: Label 'The primary key of the table cannot contain more than one field.';
        FieldLookupNotPossibleLbl: Label 'Lookup in this field is not possible.';
        TableGUID: Guid;
        Value: Text[250];
        FilterType: Option FixedFilter,DocumentField;
        TemplateNo: Code[20];
        TemplFieldType: Option Header,Line;
        ShowType: Boolean;

    internal procedure SetParam(NewTemplateNo: Code[20]; NewTemplFieldType: Option Header,Line; NewGUID: Guid; NewShowType: Boolean)
    begin
        TemplateNo := NewTemplateNo;
        TableGUID := NewGUID;
        TemplFieldType := NewTemplFieldType;
        ShowType := NewShowType;
    end;

    internal procedure GetTableFilterID(): Guid
    var
        CDCTableFilterField: Record "CDC Table Filter Field";
    begin
        CDCTableFilterField.SETRANGE("Table Filter GUID", TableGUID);
        IF NOT CDCTableFilterField.ISEMPTY THEN
            EXIT(TableGUID);
    end;

    internal procedure SetValue(NewValue: Text[250])
    var
        CDCTableFilterField: Record "CDC Table Filter Field";
    begin
        CDCTableFilterField.SETRANGE("Table Filter GUID", TableGUID);
        CDCTableFilterField.SETRANGE("Field No.", Rec."No.");
        IF (NewValue = '') AND (FilterType = 0) THEN BEGIN
            IF CDCTableFilterField.FINDFIRST THEN
                CDCTableFilterField.DELETE;
            EXIT;
        END;

        IF NOT CDCTableFilterField.FINDFIRST THEN BEGIN
            CDCTableFilterField."Table Filter GUID" := TableGUID;
            CDCTableFilterField."Table No." := Rec.TableNo;
            CDCTableFilterField."Field No." := Rec."No.";
            CDCTableFilterField.INSERT;
        END;

        IF CDCTableFilterField_SetValues(CDCTableFilterField, NewValue, FilterType, TemplateNo, TemplFieldType) THEN
            CDCTableFilterField.MODIFY(TRUE)
        ELSE
            CDCTableFilterField.DELETE;
    end;

    internal procedure CDCTableFilterField_SetValues(var CDCTableFilterField: Record "CDC Table Filter Field"; var Value: Text[250]; var FilterType: Option "Fixed Filter","Document Field"; TemplateNo: Code[20]; TempFieldType: Integer): Boolean
    var
        "Field": Record "Field";
        //CDCCaptureManagement: Codeunit "CDC Capture Management";
        TableFilterRecordRef: RecordRef;
        FieldRef: FieldRef;
    begin
        CDCTableFilterField."Value (Text)" := '';
        CDCTableFilterField."Value (Integer)" := 0;
        CDCTableFilterField."Value (Date)" := 0D;
        CDCTableFilterField."Value (Decimal)" := 0;
        CDCTableFilterField."Value (Boolean)" := FALSE;
        CDCTableFilterField."Template No." := '';
        CDCTableFilterField."Template Field Type" := 0;
        CDCTableFilterField."Template Field Code" := '';
        CDCTableFilterField."Filter View" := '';

        IF FilterType = FilterType::"Fixed Filter" THEN BEGIN
            Field.GET(CDCTableFilterField."Table No.", CDCTableFilterField."Field No.");
            IF NOT (Field.Type IN [Field.Type::Code, Field.Type::Text, Field.Type::Date, Field.Type::Decimal, Field.Type::Boolean, Field.Type::
              Integer, Field.Type::Option])
            THEN
                ERROR(PrimaryKeyOnlyOneFieldLbl, FORMAT(Field.Type));

            TableFilterRecordRef.OPEN(CDCTableFilterField."Table No.");
            FieldRef := TableFilterRecordRef.FIELD(CDCTableFilterField."Field No.");
            FieldRef.SETFILTER(Value);
            CDCTableFilterField.VALIDATE("Filter View", TableFilterRecordRef.GETVIEW);
        END ELSE BEGIN
            CDCTableFilterField."Template No." := TemplateNo;
            CDCTableFilterField."Template Field Type" := TempFieldType;
            CDCTableFilterField."Template Field Code" := Value;
        END;

        CDCTableFilterField."Filter Type" := FilterType;
        CDCTableFilterField.GetValues(Value, FilterType);

        EXIT(TRUE);
    end;

    internal procedure LookupValue(var NewValue: Text[250]): Boolean
    var
        CDCTempLookupRecordID: Record "CDC Temp. Lookup Record ID";
        CDCCDCTableFilterField: Record "CDC Table Filter Field";
        CDCTemplateField: Record "CDC Template Field";
        CDCRecordIDMgt: Codeunit "CDC Record ID Mgt.";
        RecordRef: RecordRef;
        FieldRef: FieldRef;
        KeyRef: KeyRef;
    begin
        IF FilterType = 0 THEN BEGIN
            IF Rec.Type = Rec.Type::Option THEN BEGIN
                CDCRecordIDMgt_LookupOptionString(Rec.TableNo, Rec."No.", NewValue);
                EXIT(TRUE);
            END;

            CDCTempLookupRecordID."Table No." := GetTableNo();

            IF CDCTempLookupRecordID."Table No." = 0 THEN
                ERROR(FieldLookupNotPossibleLbl);

            CDCTempLookupRecordID."Record ID Tree ID" :=
              CDCRecordIDMgt.GetRecIDTreeID2(CDCTempLookupRecordID."Table No.", Rec."No.", TableGUID, NewValue);

            CODEUNIT.RUN(CODEUNIT::"CDC Record ID Lookup", CDCTempLookupRecordID);

            IF CDCTempLookupRecordID."Lookup Mode" = CDCTempLookupRecordID."Lookup Mode"::OK THEN BEGIN
                IF CDCRecordIDMgt_GetTableNoFromRecID(CDCTempLookupRecordID."Record ID Tree ID") = 0 THEN
                    EXIT;
                RecordRef.OPEN(CDCRecordIDMgt_GetTableNoFromRecID(CDCTempLookupRecordID."Record ID Tree ID"));
                KeyRef := RecordRef.KEYINDEX(RecordRef.CURRENTKEYINDEX);
                IF KeyRef.FIELDCOUNT > 1 THEN
                    ERROR(PrimaryKeyOnlyOneFieldLbl);
                FieldRef := KeyRef.FIELDINDEX(1);
                NewValue := CDCRecordIDMgt.GetKeyValue(CDCTempLookupRecordID."Record ID Tree ID", FieldRef.NUMBER);
                EXIT(TRUE);
            END;
        END ELSE BEGIN
            CDCTemplateField.SETRANGE("Template No.", TemplateNo);
            CDCTemplateField.SETRANGE(Type, TemplFieldType);
            IF NewValue <> '' THEN
                IF CDCTemplateField.GET(TemplateNo, TemplFieldType, NewValue) THEN;
            IF PAGE.RUNMODAL(0, CDCTemplateField) = ACTION::LookupOK THEN BEGIN
                NewValue := CDCTemplateField.Code;
                EXIT(TRUE);
            END;
        END;
    end;

    internal procedure CDCRecordIDMgt_LookupOptionString(TableID: Integer; FldNo: Integer; var NewValue: Text[250]): Boolean
    var
        TempCDCLookupValueTemp: Record "CDC Lookup Value Temp" temporary;
        RecordRef: RecordRef;
        SourceNoFieldRef: FieldRef;
    begin
        RecordRef.OPEN(TableID);
        SourceNoFieldRef := RecordRef.FIELD(FldNo);
        ParseOptionString(SourceNoFieldRef.OPTIONCAPTION, TempCDCLookupValueTemp);

        TempCDCLookupValueTemp.SETRANGE(Value, NewValue);
        TempCDCLookupValueTemp.SETRANGE(Value);
        IF TempCDCLookupValueTemp.FindFirst() THEN;
        IF PAGE.RUNMODAL(0, TempCDCLookupValueTemp) = ACTION::LookupOK THEN BEGIN
            NewValue := TempCDCLookupValueTemp.Value;
            EXIT(TRUE);
        END;
    end;

    local procedure ParseOptionString(TextOptString: Text[250]; var TempCDCLookupValueTemp: Record "CDC Lookup Value Temp" temporary)
    var
        Pos: Integer;
    begin
        REPEAT
            Pos := STRPOS(TextOptString, ',');

            TempCDCLookupValueTemp."Entry No." += 1;
            IF Pos <> 0 THEN
                TempCDCLookupValueTemp.Value := COPYSTR(TextOptString, 1, Pos - 1)
            ELSE
                TempCDCLookupValueTemp.Value := COPYSTR(TextOptString, 1);
            TempCDCLookupValueTemp.Insert();

            TextOptString := COPYSTR(TextOptString, Pos + 1);
        UNTIL Pos = 0;
    end;

    internal procedure CDCRecordIDMgt_GetTableNoFromRecID(RecIDTreeID: Integer): Integer
    var
        CDCRecordIDTree: Record "CDC Record ID Tree";
    begin
        IF CDCRecordIDTree.GET(RecIDTreeID) THEN
            EXIT(CDCRecordIDTree."Table No.");
    end;

    internal procedure GetTableNo(): Integer
    var
        RecordRef: RecordRef;
        FieldRef: FieldRef;
        KeyRef: KeyRef;
    begin
        IF Rec.RelationTableNo <> 0 THEN
            EXIT(Rec.RelationTableNo);

        RecordRef.OPEN(Rec.TableNo);
        KeyRef := RecordRef.KEYINDEX(RecordRef.CURRENTKEYINDEX);
        FieldRef := KeyRef.FIELDINDEX(1);
        IF Rec."No." = FieldRef.NUMBER THEN
            EXIT(Rec.TableNo)
        ELSE
            EXIT(Rec.RelationTableNo);
    end;
}
