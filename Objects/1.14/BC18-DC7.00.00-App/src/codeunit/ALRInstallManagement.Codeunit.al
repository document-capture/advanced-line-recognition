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
        CDCTemplateField: Record "CDC Template Field";
    begin
        if (ALRVersion < 14) then begin
            CDCTemplateField.SetRange(Type, CDCTemplateField.Type::Line);
            CDCTemplateField.SetFilter("Replacement Field", '<>%1', '');
            if CDCTemplateField.IsEmpty then
                exit;
            CDCTemplateField.ModifyAll("Replacement Field Type", CDCTemplateField."Replacement Field Type"::Line);
        end;
    end;

    // Function to determine the current dataversion from isolated storage
    internal procedure GetDataVersion(): Integer
    begin
        ALRVersion := 0;
        if IsolatedStorage.Contains(ALRDataVersionLbl, DataScope::Module) then
            if IsolatedStorage.Get(ALRDataVersionLbl, DataScope::Module, IsolatedStorageValue) then
                if Evaluate(ALRVersion, IsolatedStorageValue) then;
        exit(ALRVersion);
    end;
    // Function to update the dataversion to prevent record modifications on next app install/update
    local procedure UpdateDataVersion()
    begin
        IsolatedStorage.Set(ALRDataVersionLbl, FORMAT(14), DataScope::Module);
    end;
}
