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
        addafter("Use Vendor/Customer Item Nos.")
        {
            field("Auto PO search"; Rec."Auto PO search")
            {
                ToolTip = 'Enables the automatic search for purchase order numbers.';
                ApplicationArea = All;
            }
            field("Auto PO search filter"; Rec."Auto PO search filter")
            {
                ApplicationArea = All;
                ToolTip = 'Filter string that is used during automatic search for PO numbers.';
            }
        }
    }
}
