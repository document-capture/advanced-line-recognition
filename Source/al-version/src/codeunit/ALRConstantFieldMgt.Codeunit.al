codeunit 61006 "ALR Constant Field Mgt."
{
    var
        Document: Record "CDC Document";

    internal procedure GetConstantValue(DocumentNo: code[20]; Constant: Code[20]; Word: Text[1024]; Handled: Boolean)
    var
        CaptureMgt: Codeunit "CDC Capture Management";
    begin
        case Constant of
            'SOURCENO':
                begin
                    SetDocument(DocumentNo);
                    Word := GetSourceNo();
                    Handled := true;
                end;
            'SOURCENAME':
                begin
                    SetDocument(DocumentNo);
                    Word := GetSourceName();
                    Handled := true;
                end;
            'IMPORTDATE':
                begin
                    SetDocument(DocumentNo);
                    Word := GetImportDate();
                    Handled := true;
                end;
        end;

        if Handled then begin
            //        CaptureMgt.UpdateFieldValue(Document."No.", PageNo, LineNo, Field, Word, false, false);
        end;
    end;

    //internal procedure GetConstantFieldValue()

    internal procedure ConvertToConstant(FixedReplacementValue: Text[200])
    begin
        if IsConstant(FixedReplacementValue) then
            FixedReplacementValue := UpperCase(FixedReplacementValue);
    end;

    local procedure IsConstant(FixedReplacementValue: Text[200]): Boolean
    begin
       
    end;

    local procedure SetDocument(DocumentNo: Code[20])
    begin
        if not Document.get(DocumentNo) then
            exit;
    end;

    local procedure GetSourceNo(): Text
    begin

        exit(Document."Source Record No.");
    end;

    local procedure GetSourceName(): Text
    begin
        exit(Document."Source Record Name");
    end;

    local procedure GetImportDate(): Text
    begin
        exit(Format(DT2Date(Document."Imported Date-Time")));
    end;


}
