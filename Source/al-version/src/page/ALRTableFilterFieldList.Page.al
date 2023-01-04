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
        TableFilterField: Record "CDC Table Filter Field";
        RecIDMgt: Codeunit "CDC Record ID Mgt.";
    begin
        TableFilterField.SETRANGE("Table Filter GUID", TableGUID);
        TableFilterField.SETRANGE("Field No.", Rec."No.");
        IF NOT TableFilterField.FINDFIRST THEN
            CLEAR(TableFilterField);
        TableFilterField.GetValues(Value, FilterType);
    end;

    var
        PrimaryKeyOnlyOneFieldLbl: Label 'The primary key of the table cannot contain more than one field.';
        FieldLookupNotPossibleLbl: Label 'Lookup in this field is not possible.';
        TableGUID: Guid;
        Value: Text[250];
        FilterType: Option FixedFilter,DocumentField;
        TemplateNo: Code[20];
        TemplFieldType: Option Header,Line;
        [InDataSet]
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
        TableFilterField: Record "CDC Table Filter Field";
    begin
        TableFilterField.SETRANGE("Table Filter GUID", TableGUID);
        IF NOT TableFilterField.ISEMPTY THEN
            EXIT(TableGUID);
    end;

    internal procedure SetValue(NewValue: Text[250])
    var
        TableFilterField: Record "CDC Table Filter Field";
    begin
        TableFilterField.SETRANGE("Table Filter GUID", TableGUID);
        TableFilterField.SETRANGE("Field No.", Rec."No.");
        IF (NewValue = '') AND (FilterType = 0) THEN BEGIN
            IF TableFilterField.FINDFIRST THEN
                TableFilterField.DELETE;
            EXIT;
        END;

        IF NOT TableFilterField.FINDFIRST THEN BEGIN
            TableFilterField."Table Filter GUID" := TableGUID;
            TableFilterField."Table No." := Rec.TableNo;
            TableFilterField."Field No." := Rec."No.";
            TableFilterField.INSERT;
        END;

        IF TableFilterField_SetValues(TableFilterField, NewValue, FilterType, TemplateNo, TemplFieldType) THEN
            TableFilterField.MODIFY(TRUE)
        ELSE
            TableFilterField.DELETE;
    end;

    internal procedure TableFilterField_SetValues(var TableFilterField: Record "CDC Table Filter Field"; var Value: Text[250]; var FilterType: Option "Fixed Filter","Document Field"; TemplateNo: Code[20]; TempFieldType: Integer): Boolean
    var
        "Field": Record "Field";
        CaptureMgt: Codeunit "CDC Capture Management";
        RecRef: RecordRef;
        FieldRef: FieldRef;
    begin
        TableFilterField."Value (Text)" := '';
        TableFilterField."Value (Integer)" := 0;
        TableFilterField."Value (Date)" := 0D;
        TableFilterField."Value (Decimal)" := 0;
        TableFilterField."Value (Boolean)" := FALSE;
        TableFilterField."Template No." := '';
        TableFilterField."Template Field Type" := 0;
        TableFilterField."Template Field Code" := '';
        TableFilterField."Filter View" := '';

        IF FilterType = FilterType::"Fixed Filter" THEN BEGIN
            Field.GET(TableFilterField."Table No.", TableFilterField."Field No.");
            IF NOT (Field.Type IN [Field.Type::Code, Field.Type::Text, Field.Type::Date, Field.Type::Decimal, Field.Type::Boolean, Field.Type::
              Integer, Field.Type::Option])
            THEN
                ERROR(PrimaryKeyOnlyOneFieldLbl, FORMAT(Field.Type));

            RecRef.OPEN(TableFilterField."Table No.");
            FieldRef := RecRef.FIELD(TableFilterField."Field No.");
            FieldRef.SETFILTER(Value);
            TableFilterField.VALIDATE("Filter View", RecRef.GETVIEW);
        END ELSE BEGIN
            TableFilterField."Template No." := TemplateNo;
            TableFilterField."Template Field Type" := TempFieldType;
            TableFilterField."Template Field Code" := Value;
        END;

        TableFilterField."Filter Type" := FilterType;
        TableFilterField.GetValues(Value, FilterType);

        EXIT(TRUE);
    end;

    internal procedure LookupValue(var NewValue: Text[250]): Boolean
    var
        CDCTempLookupRecordID: Record "CDC Temp. Lookup Record ID";
        CDCTableFilterField: Record "CDC Table Filter Field";
        CDCTemplateField: Record "CDC Template Field";
        RecIDMgt: Codeunit "CDC Record ID Mgt.";
        RecRef: RecordRef;
        KeyRef: KeyRef;
        FieldRef: FieldRef;
    begin
        IF FilterType = 0 THEN BEGIN
            IF Rec.Type = Rec.Type::Option THEN BEGIN
                RecIDMgt_LookupOptionString(Rec.TableNo, Rec."No.", NewValue);
                EXIT(TRUE);
            END;

            CDCTempLookupRecordID."Table No." := GetTableNo;

            IF CDCTempLookupRecordID."Table No." = 0 THEN
                ERROR(FieldLookupNotPossibleLbl);

            CDCTempLookupRecordID."Record ID Tree ID" :=
              RecIDMgt.GetRecIDTreeID2(CDCTempLookupRecordID."Table No.", Rec."No.", TableGUID, NewValue);

            CODEUNIT.RUN(CODEUNIT::"CDC Record ID Lookup", CDCTempLookupRecordID);

            IF CDCTempLookupRecordID."Lookup Mode" = CDCTempLookupRecordID."Lookup Mode"::OK THEN BEGIN
                IF RecIDMgt_GetTableNoFromRecID(CDCTempLookupRecordID."Record ID Tree ID") = 0 THEN
                    EXIT;
                RecRef.OPEN(RecIDMgt_GetTableNoFromRecID(CDCTempLookupRecordID."Record ID Tree ID"));
                KeyRef := RecRef.KEYINDEX(RecRef.CURRENTKEYINDEX);
                IF KeyRef.FIELDCOUNT > 1 THEN
                    ERROR(PrimaryKeyOnlyOneFieldLbl);
                FieldRef := KeyRef.FIELDINDEX(1);
                NewValue := RecIDMgt.GetKeyValue(CDCTempLookupRecordID."Record ID Tree ID", FieldRef.NUMBER);
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

    internal procedure RecIdMgt_LookupOptionString(TableID: Integer; FldNo: Integer; var NewValue: Text[250]): Boolean
    var
        CDCLookupValueTemp: Record "CDC Lookup Value Temp" temporary;
        RecRef: RecordRef;
        SourceNoFieldRef: FieldRef;
    begin
        RecRef.OPEN(TableID);
        SourceNoFieldRef := RecRef.FIELD(FldNo);
        ParseOptionString(SourceNoFieldRef.OPTIONCAPTION, CDCLookupValueTemp);

        CDCLookupValueTemp.SETRANGE(Value, NewValue);
        CDCLookupValueTemp.SETRANGE(Value);
        IF CDCLookupValueTemp.FINDFIRST THEN;
        IF PAGE.RUNMODAL(0, CDCLookupValueTemp) = ACTION::LookupOK THEN BEGIN
            NewValue := CDCLookupValueTemp.Value;
            EXIT(TRUE);
        END;
    end;

    local procedure ParseOptionString(TextOptString: Text[250]; var LookupTableTemp: Record "CDC Lookup Value Temp" temporary)
    var
        Pos: Integer;
    begin
        REPEAT
            Pos := STRPOS(TextOptString, ',');

            LookupTableTemp."Entry No." += 1;
            IF Pos <> 0 THEN
                LookupTableTemp.Value := COPYSTR(TextOptString, 1, Pos - 1)
            ELSE
                LookupTableTemp.Value := COPYSTR(TextOptString, 1);
            LookupTableTemp.INSERT;

            TextOptString := COPYSTR(TextOptString, Pos + 1);
        UNTIL Pos = 0;
    end;

    internal procedure RecIDMgt_GetTableNoFromRecID(RecIDTreeID: Integer): Integer
    var
        CDCRecordIDTree: Record "CDC Record ID Tree";
    begin
        IF CDCRecordIDTree.GET(RecIDTreeID) THEN
            EXIT(CDCRecordIDTree."Table No.");
    end;

    internal procedure GetTableNo(): Integer
    var
        RecRef: RecordRef;
        KeyRef: KeyRef;
        FieldRef: FieldRef;
    begin
        IF Rec.RelationTableNo <> 0 THEN
            EXIT(Rec.RelationTableNo);

        RecRef.OPEN(Rec.TableNo);
        KeyRef := RecRef.KEYINDEX(RecRef.CURRENTKEYINDEX);
        FieldRef := KeyRef.FIELDINDEX(1);
        IF Rec."No." = FieldRef.NUMBER THEN
            EXIT(Rec.TableNo)
        ELSE
            EXIT(Rec.RelationTableNo);
    end;
}
