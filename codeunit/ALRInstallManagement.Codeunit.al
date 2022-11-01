codeunit 50113 "ALR Install Management"
{
    Subtype = Install;

    var
        ALRDataVersionLbl: Label 'ALRDataVersion', Locked = true;
        IsolatedStorageValue: Text;
        ALRVersion: Integer;

    // procedure is executed in every existing company, when the app is installed
    trigger OnInstallAppPerCompany()
    begin
        GetDataVersion();

        SetReplacementFieldTypeToLine();

        UpdateDataVersion();
    end;

    // event is executed, when a new company is created and initialized
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Company-Initialize", 'OnCompanyInitialize', '', false, false)]
    local procedure CompanyInitialize()
    begin

    end;

    local procedure SetReplacementFieldTypeToLine()
    var
        CDCTemplateField: Record "CDC Template Field";
    begin
        if (ALRVersion < 15) then begin
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
        IsolatedStorage.Set(ALRDataVersionLbl, FORMAT(15), DataScope::Module);
    end;
}
