pageextension 61002 "ALR Template Card" extends "CDC Template Card"
{
    ContextSensitiveHelpPage = 'template-card-options';
    layout
    {
        addafter("Purch. Validate VAT Calc.")
        {
            field("ALR Line Validation Type"; Rec."ALR Line Validation Type")
            {
                ApplicationArea = All;
                ToolTip = 'Select if you want to use the default line validation from the template codeunit or the Adv. line recognition validation';
            }
        }
    }
}
