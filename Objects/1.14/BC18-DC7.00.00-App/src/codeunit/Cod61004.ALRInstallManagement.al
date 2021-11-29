codeunit 61004 "ALR Install Management"
{
    Subtype = Install;

    var
        ALRDataVersionLbl: Label 'ALRDataVersion';
        IsolatedStorageValue: Text;
        ALRVersion: Integer;

    trigger OnInstallAppPerCompany()
    begin
        GetDataVersion();

        SetReplacementFieldTypeToLine();

        UpdateDataVersion();
    end;

    local procedure SetReplacementFieldTypeToLine()
    var
        TemplateField: Record "CDC Template Field";
        UpdateReplacementField: Boolean;
    begin
        if (ALRVersion < 14) then begin
            TemplateField.SetRange(Type, TemplateField.Type::Line);
            TemplateField.SetFilter("Replacement Field", '<>%1', '');
            if TemplateField.IsEmpty then
                exit;
            TemplateField.ModifyAll("Replacement Field Type", TemplateField."Replacement Field Type"::Line);
        end;
    end;

    // Function to determine the current dataversion from isolated storage
    internal procedure GetDataVersion(): Integer
    begin
        ALRVersion := 0;
        if IsolatedStorage.Contains(ALRDataVersionLbl, DataScope::Module) then begin
            if IsolatedStorage.Get(ALRDataVersionLbl, DataScope::Module, IsolatedStorageValue) then begin
                if Evaluate(ALRVersion, IsolatedStorageValue) then;
            end;
        end;
        exit(ALRVersion);
    end;
    // Function to update the dataversion to prevent record modifications on next app install/update
    local procedure UpdateDataVersion()
    begin
        IsolatedStorage.Set(ALRDataVersionLbl, FORMAT(14), DataScope::Module);
    end;
}
