pageextension 61003 "ALR DocList Ext" extends "CDC Document List With Image"
{
    ContextSensitiveHelpPage = 'document-list';
    actions
    {
        addafter(RegisterBatch)
        {
            action(TestLookupFieldValue)
            {
                ApplicationArea = All;
                Caption = 'Get Lookup Field Value';
                Description = 'TODO';
                Image = Open;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'TODO';
                Enabled = IsDocument;

                trigger OnAction()
                var
                    TableFilterField: Record "CDC Table Filter Field";
                    TemplateField: Record "CDC Template Field";
                    recref: RecordRef;
                    fldref: FieldRef;
                    LookupRecID: Record "CDC Temp. Lookup Record ID" temporary;
                    recidmgt: Codeunit "CDC Record ID Mgt.";
                    alr: Codeunit "ALR Advanced Line Capture";
                    handled: Boolean;
                begin
                    alr.GetLookupFieldValue(Rec, 0);
                    //                     if not TemplateField.Get(Rec."Template No.", TemplateField.Type::Header, 'OURDOCNO') then
                    //                         exit;

                    //                     TableFilterField.SETRANGE("Table Filter GUID", TemplateField."Source Table Filter GUID");
                    //                     if TableFilterField.IsEmpty then
                    //                         exit;

                    //                     //LookupRecID."Table No." := Category."Source Table No.";

                    //                     /* IF Text <> '' THEN
                    //                          LookupRecID."Record ID Tree ID" :=
                    //                            recidmgt.GetRecIDTreeID2(LookupRecID."Table No.", Category."Source Field No.", Category."Document Category GUID", Text);

                    //                      TempLookupRecID."Table Filter GUID" := Category."Document Category GUID";


                    //  */
                    //                     recref.Open(TemplateField."Source Table No.");
                    //                     fldref := recref.Field(TableFilterField."Field No.");
                    //                     FilterRecRefWithLookupRecID(recref, TemplateField, Rec);
                    //                     fldref := recref.Field(TemplateField."Source Field No.");
                    //                     Message('%1', fldref.Value);

                    //TemplateField."Source Table Filter GUID"
                    //RecIDMgt.ShowTableFields("Source Table No.", "Template No.", Type, TRUE, "Source Table Filter GUID");
                end;
            }
        }
        addafter("Remove Template Field")
        {
            action(MasterTemplate)
            {
                ApplicationArea = All;
                Caption = 'Master Template';
                Description = 'Open master template of current selected Document';
                Image = Open;
                Promoted = true;
                PromotedCategory = Category6;
                ToolTip = 'Open master template of current selected Document';
                Enabled = IsDocument;

                trigger OnAction()
                begin
                    TemplateHelper.OpenMasterTemplate(Rec, IsXMLTemplate);
                end;
            }

            action(IdentificationTemplate)
            {
                ApplicationArea = All;
                Caption = 'Ident. Template';
                Description = 'Open identification template of current selected Document';
                Image = Find;
                Promoted = true;
                PromotedCategory = Category6;
                ToolTip = 'Open identification template of current selected Document';
                Enabled = IsDocument;

                trigger OnAction()
                begin
                    TemplateHelper.OpenIdentificationTemplate(Rec, IsXMLTemplate);
                end;
            }
            action(DocCategory)
            {
                ApplicationArea = All;
                Caption = 'Document Category';
                Description = 'Open document category card';
                Image = Category;
                Promoted = true;
                PromotedCategory = Category6;
                ToolTip = 'Open document category card';
                Enabled = IsDocument;

                trigger OnAction()
                begin
                    Rec.TestField("Document Category Code");
                    TemplateHelper.OpenDocumentCategoryCard(Rec."Document Category Code");
                end;
            }
            action(CopySettingToMaster)
            {
                ApplicationArea = All;
                Caption = 'Copy field config to Master';
                Description = 'Copies the documents XML configuration to the Master template';
                Image = Copy;
                Promoted = true;
                PromotedCategory = Category6;
                ToolTip = 'Copies the documents XML configuration to the Master template';
                Visible = IsXMLTemplate;

                trigger OnAction()
                var

                begin
                    if not IsXMLTemplate then
                        exit;

                    TemplateHelper.CopyFieldSettingsToMasterTemplate(Rec);
                end;
            }
        }
    }

    var
        [InDataSet]
        IsXMLTemplate: Boolean;
        [InDataSet]
        IsDocument: Boolean;
        TemplateHelper: Codeunit "ALR Template Helper";

    trigger OnAfterGetCurrRecord()
    begin
        IsXMLTemplate := Rec."File Type" = Rec."File Type"::XML;
        IsDocument := Rec."No." <> '';
    end;
}