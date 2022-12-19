codeunit 61004 "ALR Install Management"
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

        if ALRVersion < 15 then
            SetReplacementFieldTypeToLine();

        if ALRVersion < 16 then
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
        IsolatedStorage.Set(ALRDataVersionLbl, FORMAT(16), DataScope::Module);
    end;

    local procedure UpdateEmptyValueReplacementOptions()
    var
        TemplateField: Record "CDC Template Field";
        ModifyField: Boolean;
    begin
        if TemplateField.FindSet(true, false) then
            repeat
                Clear(ModifyField);
                if (TemplateField."Replacement Field Type" = TemplateField."Replacement Field Type"::Header) and (TemplateField."Replacement Field" <> '') then begin
                    TemplateField."Empty value handling" := TemplateField."Empty value handling"::CopyHeaderFieldValue;
                    ModifyField := true;
                end;


                if (TemplateField."Replacement Field Type" = TemplateField."Replacement Field Type"::Line) and (TemplateField."Replacement Field" <> '') then begin
                    TemplateField."Empty value handling" := TemplateField."Empty value handling"::CopyLineFieldValue;
                    ModifyField := true;
                end;

                if (TemplateField."Replacement Field Type" = TemplateField."Replacement Field Type"::FixedValue) and (TemplateField."Fixed Replacement Value" <> '') then begin
                    TemplateField."Empty value handling" := TemplateField."Empty value handling"::FixedValue;
                    ModifyField := true;
                end;

                if TemplateField."Copy Value from Previous Value" then begin
                    TemplateField."Empty value handling" := TemplateField."Empty value handling"::CopyPrevLineValue;
                    ModifyField := true;
                end;

                if ModifyField then
                    TemplateField.Modify();
            until TemplateField.Next() = 0;
    end;
}
