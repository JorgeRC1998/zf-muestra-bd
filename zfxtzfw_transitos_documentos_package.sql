CREATE OR REPLACE PACKAGE         "ZFXTZFW_TRANSITOS_DOCUMENTOS" authid current_user
is
    procedure Insert$(
        iclbRecord                      in      clob,
        oclbXML                         out     clob);
    procedure Update$(
        iclbRecord                      in      clob,
        oclbXML                         out     clob);
    procedure UpdateCntrlIngresos(
        iclbRecord                      in      clob,
        oclbXML                         out     clob);
    procedure Insert$Auditoria(
        iclbRecord                      in      clob,
        oclbXML                         out     clob);
    procedure Create$FromXMLLst(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure Update$ControlIngresosXML(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure UpdateEntRegIng$(
        iclbRecord                      in      clob,
        oclbXML                         out     clob);
    procedure Create$EntRegIngXMLLst(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure InsertEntRegIng$(
        iclbRecord                      in      clob,
        oclbXML                         out     clob);
    procedure Delete$(
        iclbRecord                      in      clob,
        oclbXML                         out     clob);
    procedure XQuery(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XControlIngresos(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XControlTiempoBloqueados(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XControlTiempo(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XControlTiempoProvisional(
        iclbParam              in clob,
        oclbXML                out clob);
    procedure Query$Definitivo(
        iclbParam           in clob,
        oclbXML             out clob);  
    procedure Query$ControlTiempo(
        iclbParam           in clob,
        oclbXML             out clob); 
    procedure XQueryEstado(
        iclbParam              in clob,
        oclbXML                out clob);
    procedure xQueryDigitalizacion(
        iclbParam              in clob,
        oclbXML                out clob);
    procedure UpdateAutoriza(
        iclbRecord             in      clob,
        oclbXML                out     clob); 
    procedure Update$AutorizadoXML(
        iclbParam              in clob,
        oclbXML                out clob);
    procedure xQueryAutorizaDoc(
        iclbParam              in clob,
        oclbXML                out clob);
    procedure xQuerySalidas(
        iclbParam              in clob,
        oclbXML                out clob);        
    procedure XQueryImagenesXPlaca(
        iclbParam              in clob,
        oclbXML                out clob);                
    procedure xQueryAutoriza(
        iclbParam              in clob,
        oclbXML                out clob);
    procedure Query$Formulario$Dup(
        iclbParam              in clob,
        oclbXML                out clob);        
    procedure XCnsltaMovCamiones(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XEntrdasRegIngreso(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XEntrdasRegTransitos(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XUsuClficadoCnslta(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XUsuClficadoInvntrio(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XUsuClficadoRegDoc(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XVerificarTransito(
        iclbParam                       in      clob,
        oclbXML                         out     clob);

    procedure XQueryTipoTransito(
        iclbParam                       in      clob,
        oclbXML                         out     clob);    

    /*procedure XQuery$FeDigitalizacion(
        iclbParam           in clob,
        oclbXML             out clob);    */

    procedure QryNotifDocRechaSuspe(
        iclbRecord                     in      clob,
        oclbXML                        out     clob);

    procedure ConsultaGranel_Nal(
        iclbRecord                     in      clob,
        oclbXML                        out     clob);

    procedure ConsEntrega_Parcial(
        iclbRecord                     in      clob,
        oclbXML                        out     clob);

    procedure Update$Auditoria(
        iclbParam                      in      clob,
        oclbXML                        out     clob);
    procedure QueryTipoDesprecinte(         
         iclbParam                      in      clob,
         oclbXML                        out     clob);
    procedure QueryModTipoDesprecinte(         
         iclbParam                      in      clob,
         oclbXML                        out     clob);
         
    procedure UpdateTipoDesprecinte(
        iclbRecord          in      clob,
        oclbXML             out     clob);
    procedure UpdateSolDesprecinte(
        iclbRecord          in      clob,
        oclbXML             out     clob);
    procedure CrearSolicitud(
        iclbRecord          in      clob,
        oclbXML             out     clob);   
    procedure xPlaca(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
end zfxtzfw_transitos_documentos;
