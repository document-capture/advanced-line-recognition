codeunit 61004 "ALR Upgrade Management"
{
    Subtype = Upgrade;

    var
        ALRDataVersionLbl: Label 'ALRDataVersion', Locked = true;
        IsolatedStorageValue: Text;
        ALRVersion: Integer;

    // procedure is executed in every existing company, when the app is installed
    trigger OnUpgradePerCompany()
    begin
        GetDataVersion();

        if ALRVersion < 15 then
            SetReplacementFieldTypeToLine();

        if ALRVersion < 17 then
            UpdateEmptyValueReplacementOptions();

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
        CDCTemplateField.SetRange(Type, CDCTemplateField.Type::Line);
        CDCTemplateField.SetFilter("Replacement Field", '<>%1', '');
        if CDCTemplateField.IsEmpty then
            exit;
        CDCTemplateField.ModifyAll("Replacement Field Type", CDCTemplateField."Replacement Field Type"::Line);
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
        IsolatedStorage.Set(ALRDataVersionLbl, FORMAT(17), DataScope::Module);
    end;

    local procedure UpdateEmptyValueReplacementOptions()
    var
        CDCTemplateField: Record "CDC Template Field";
        ModifyField: Boolean;
    begin
        CDCTemplateField.ModifyAll("Empty value handling", CDCTemplateField."Empty value handling"::Ignore);
        if CDCTemplateField.FindSet(true, false) then
            repeat
                if CDCTemplateField."Replacement Field" <> '' then begin
                    ModifyField := true;
                    case CDCTemplateField."Replacement Field Type" of
                        CDCTemplateField."Replacement Field Type"::Header:
                            CDCTemplateField."Empty value handling" := CDCTemplateField."Empty value handling"::CopyHeaderFieldValue;
                        CDCTemplateField."Replacement Field Type"::Line:
                            CDCTemplateField."Empty value handling" := CDCTemplateField."Empty value handling"::CopyLineFieldValue;
                        CDCTemplateField."Replacement Field Type"::FixedValue:
                            CDCTemplateField."Empty value handling" := CDCTemplateField."Empty value handling"::FixedValue;
                    end;
                end;

                if CDCTemplateField."Copy Value from Previous Value" then begin
                    CDCTemplateField."Empty value handling" := CDCTemplateField."Empty value handling"::CopyPrevLineValue;
                    ModifyField := true;
                end;

                if ModifyField then
                    CDCTemplateField.Modify();

            until CDCTemplateField.Next() = 0;
    end;
}
