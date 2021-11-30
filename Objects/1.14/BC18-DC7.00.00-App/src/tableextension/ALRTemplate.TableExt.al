tableextension 61001 "ALR Template" extends "CDC Template"
{
    fields
    {
        field(61000; "ALR Line Validation Type"; Option)
        {
            Caption = 'Line validation type';
            OptionMembers = TemplateCodeunit,AdvancedLineRecognition;
            OptionCaption = 'Default template codeunit,Advanced Line Recognition';
            DataClassification = CustomerContent;
        }
    }
}
