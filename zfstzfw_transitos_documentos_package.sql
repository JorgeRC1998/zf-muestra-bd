CREATE OR REPLACE PACKAGE "ZFWEB"."ZFSTZFW_TRANSITOS_DOCUMENTOS" authid current_user
is
--  Tipos/subtipos
    subtype rtytzfw_transitos_documentos           is tzfw_transitos_documentos%rowtype;
    subtype rtytzfw_camiones                       is tzfw_camiones%rowtype;
    subtype rtytzfw_archivos_dig                   is tzfw_archivos_dig%rowtype;    
    subtype rtytzfw_notificac_eventos                     is tzfw_notificac_eventos%rowtype;

--  Procedimientos
    procedure fvchBloqueoCompania(ivchCia in varchar2 default null);
    procedure Insert$(
        ircrRecord                      in      rtytzfw_transitos_documentos);
    procedure Update$(
        ircrRecord                      in       rtytzfw_transitos_documentos);
    procedure Insert$Auditoria(
        ircrRecord                      in       rtytzfw_archivos_dig,
        onmbId                          out      number  );
    procedure UpdateCntrlIngresos(
        ircrRecord                      in      rtytzfw_transitos_documentos,
        icdidentificacion               in       varchar2,
        icdusuario_ab                   in      varchar2 default null);
    procedure XQueryAutorizaDoc(
        ivchCiaUsuaria                  in  tzfw_formularios.cdcia_usuaria%type,
        ivchPlaca                       in  tzfw_transitos_documentos.cdplaca%type,
        idtFeIngreso                    in  varchar2,
        inmbTransito                    in  tzfw_transitos_documentos.nmtransito_documento%type,
        oclbXML                         out     clob);
    procedure XQuerySalidas(
        ivchPlaca                       in  tzfw_transitos_documentos.cdplaca%type,
        idtFeIngreso                    in  varchar2,
        oclbXML                         out     clob);  
   procedure XQuery$Id(
        oclbXML                         out     clob); 
   procedure Query$Definitivo$(inmbFormulario_zf in  tzfw_formularios.nmformulario_zf%type,
        vchCiaUsuaria                   in  tzfw_formularios.cdcia_usuaria%type,
        onmbRta                         out     number);   
   procedure Query$Formulario$Dup$(inmbFormulario_zf in  tzfw_formularios.nmformulario_zf%type,
         ivchCiaUsuaria     in  tzfw_formularios.cdcia_usuaria%type,
         ivchPlaca          in tzfw_transitos_documentos.cdplaca%type,
         idtFeIngreso       in tzfw_transitos_documentos.feingreso%type,
         inmbTransito       in tzfw_transitos_documentos.nmdoctransporte%type,
         onmbTotal          out     number);             
  procedure XQueryDigitalizacion(
        ivchCiaUsuaria                  in  tzfw_formularios.cdcia_usuaria%type,
        ivchPlaca                       in  tzfw_transitos_documentos.cdplaca%type,
        idtFeIngreso                    in  varchar2,
        inmbTransito                    in  tzfw_transitos_documentos.nmtransito_documento%type,
        oclbXML                         out     clob);     
   procedure XQueryImagenesXPlaca(
        icdplaca                        in      tzfw_transitos_documentos.cdplaca%type,
        idtFEINGRESO                    in      varchar2,
        oclbXML                         out     clob);             
    procedure UpdateAutoriza(
        onmbError                       out      number, 
        ovchMessaje                     out      varchar2, 
        ircrRecord                      in       rtytzfw_transitos_documentos);
    procedure XQueryAutoriza(
      	ivchCiaUsuaria                  in  tzfw_formularios.cdcia_usuaria%type,
        ivchPlaca                       in  tzfw_transitos_documentos.cdplaca%type,
        idtFeIngreso                    in  varchar2,
        oclbXML                         out     clob);
    procedure Delete$(
        ircrRecord                      in      rtytzfw_transitos_documentos);
    procedure XQuery(
        oclbXML                         out     clob);
    procedure XQueryEstado(
        icdcia_usuaria                  in      tzfw_transitos_documentos.cdcia_usuaria%type,
        icdplaca                        in      tzfw_transitos_documentos.cdplaca%type,               
        idtFEINGRESO                    in      varchar2,               
        oclbXML                         out     clob);
    procedure XControlIngresos(
        ivchFilter                      in      varchar2,
        ivchFilter2                     in      varchar2,
        ivchVencimiento                in      varchar2,
        inmbRegistros                   in      number,
        inmbLimite                      in      number,
        oclbXML                         out     clob);
   procedure Query$Formulario$Dup(inmbFormulario_zf in  tzfw_formularios.nmformulario_zf%type,
         ivchCiaUsuaria                  in  tzfw_formularios.cdcia_usuaria%type,
         ivchPlaca                       in tzfw_transitos_documentos.cdplaca%type,
         idtFeIngreso                    in tzfw_transitos_documentos.feingreso%type,
         inmbTransito                    in tzfw_transitos_documentos.nmtransito_documento%type,
         ivchTipo                        in tzfw_transitos_documentos.cdtipo_documento%type,                           
         inmbId                          in  tzfw_formularios.id%type,
         oclbXML                         out     clob);
    procedure XControlTiempoBloqueados(
        ivchFilter                      in      varchar2,
        oclbXML                         out     clob);
    procedure XControlTiempoBloqueadosP(
        ivchCia                         in varchar2,
        inmbCantidad                    out number);
    procedure XControlTiempo(
        ivchFilter                      in      varchar2,
        ivchCia                         in      varchar2,
        inmbRegistros                   in      number,
        inmbLimite                      in      number,
        oclbXML                         out     clob);
    procedure XControlTiempoProvisional(
        ivchFilter                      in      varchar2,
        ivchCia                         in tzfw_transitos_documentos.cdcia_usuaria%type,        
        oclbXML                         out     clob);
    procedure Query$ControlTiempo(
        ivchFormulario                  in tzfw_formularios.nmformulario_zf%type,
        ivchPlaca                       in tzfw_transitos_documentos.cdplaca%type,
        ivchCia                         in tzfw_transitos_documentos.cdcia_usuaria%type,
        oclbXML                         out     clob);
    procedure Query$Definitivo(
        inmbFormulario_zf in tzfw_formularios.nmformulario_zf%type,
        vchCiaUsuaria     in tzfw_formularios.cdcia_usuaria%type,
        oclbXML                         out     clob);
    procedure XCnsltaMovCamiones(
        ivchFilter                      in      varchar2,
        oclbXML                         out     clob);
    procedure XEntrdasRegIngreso(
        ivchFilter                      in      varchar2,
        ivchTransito                    in      varchar2,
        oclbXML                         out     clob);
    procedure XEntrdasRegTransitos(
        ivchFilter                      in      varchar2,
        ivchTransito                    in      varchar2,
        oclbXML                         out     clob);
    procedure XUsuClficadoCnslta(
        ivchFilter                      in      varchar2,
        oclbXML                         out     clob);
    procedure XUsuClficadoInvntrio(
        ivchFilter                      in      varchar2,
        ivchTransito                    in      varchar2,
        oclbXML                         out     clob);
    procedure XUsuClficadoRegDoc(
        ivchFilter                      in      varchar2,
        oclbXML                         out     clob);
    procedure XVerificarTransito(
        ivchFilter                      in      varchar2,
        ivchTransito                    in      varchar2,
        oclbXML                         out     clob);
    procedure XQueryTipoTransito(
        inmtransito_documento           in      varchar2,
        oclbXML                         out     clob);


/*    procedure XQuery$FeDigitalizacion(
        icdcia_usuaria          in TZFW_TRANSITOS_DOCUMENTOS.CDCIA_USUARIA%type,
        icdplaca                in TZFW_TRANSITOS_DOCUMENTOS.CDPLACA%type,
        ifedigitalizacion       IN TZFW_TRANSITOS_DOCUMENTOS.FEDIGITALIZACION%type,
        clbXML                  out   clob);    */

procedure QryNotifDocRechaSuspe(
    onmbErr                         out     number,
    ovchErrMsg                      out     varchar2,
    icdcia_usuaria                   in     varchar2,    
    icd_usuario                     in      varchar2,
    onmbAprobado                    out     number,
    oclbXML                         out     clob);

procedure ConsultaGranel_Nal(
    onmbErr                         out     number,
    ovchErrMsg                      out     varchar,
    ivchcdcia_usuaria                in     varchar,
    ivchnmdoctransporte              in     varchar,
    ivchcdtipo_documento             in     varchar,
    ovchsngranel_nal                out     varchar,
    oclbXML                         out     clob);

procedure ConsEntrega_Parcial(
    onmbErr                         out     number,
    ovchErrMsg                      out     varchar,
    ivchcdcia_usuaria                in     varchar,
    ivchnmdoctransporte              in     varchar,
    ivchcdtipo_documento             in     varchar,
    ovchsnparcial                   out     varchar,
    oclbXML                         out     clob);

procedure Update$Auditoria(
    onmbErr                         out     number,
    ovchErrMsg                      out     varchar2,
    ivchruta_final                  in      tzfw_archivos_dig.vchruta_final%type,
    ivchobservacion                 in      tzfw_archivos_dig.vchobservacion%type,
    ifeoptimizacion                 in      tzfw_archivos_dig.feoptimizacion%type,
    ivchduracion_optimizado         in      varchar2,
    inmbtamano_archiv_opti          in      tzfw_archivos_dig.nmtamano_archiv_opti%type,
    inmbId                          in      tzfw_archivos_dig.id%type);

    function SQL$$Found
        return boolean;
    function SQL$$Success
        return boolean;
        
function QueryTipoDesprecinte(         
         ivchCiaUsuaria                  in tzfw_transitos_documentos.cdcia_usuaria%type,
         ivchPlaca                       in tzfw_transitos_documentos.cdplaca%type,
         idtFeIngreso                    in varchar2,
         inmbTransito                    in tzfw_transitos_documentos.nmtransito_documento%type)
return number;  

function QueryModTipoDesprecinte(         
         ivchCiaUsuaria                  in tzfw_transitos_documentos.cdcia_usuaria%type,
         ivchPlaca                       in tzfw_transitos_documentos.cdplaca%type,
         idtFeIngreso                    in varchar2,
         inmbTransito                    in tzfw_transitos_documentos.nmtransito_documento%type)
return number;

procedure UpdateTipoDesprecinte(
    onmbError                      out      number,
    ovchMessaje                    out      varchar2,
    ircrRecord                     in       rtytzfw_transitos_documentos,
    ivchTipo                       in       tzfw_camiones.CDTIPODESPRECINTE%type,
    ivchComentario                 in       tzfw_camiones.DSCOMENTARIODESPRE%type);

procedure UpdateSolDesprecinte(
    onmbError                      out      number,
    ovchMessaje                    out      varchar2,    
    ivchPlaca                      in       tzfw_camiones.cdplaca%type,
    idtFecha                       in       varchar2,
    ivchsol                        in       tzfw_camiones.CDNROSOL%type);
    
procedure EnvioTipoDesprecinte(
    ivchPlaca                      in       tzfw_transitos_documentos.cdplaca%type,
    ivchCia                        in       tzfw_transitos_documentos.cdcia_usuaria%type,
    idtFecha                       in       tzfw_transitos_documentos.feingreso%type,
    ivchUsuario                    in       tzfw_transitos_documentos.cdusuario_aud%type,
    ivchcompania                   in       tzfw_transitos_documentos.cdcia_usuaria%type,
    onmbError                      out      number,
    ovchMessaje                    out      varchar2,
    onmbTipo                       out      number,
    ovchCorreo                     out      varchar,
    ovchTipoDespre                 out      varchar);  
    
procedure CrearSolicitud(
    ivchPlaca                      in       tzfw_transitos_documentos.cdplaca%type,
    ivchCia                        in       tzfw_transitos_documentos.cdcia_usuaria%type,
    idtFecha                       in       tzfw_transitos_documentos.feingreso%type,    
    ivchUsuario                    in       tzfw_transitos_documentos.cdusuario_aud%type,
    ivchCompania                   in       tzfw_transitos_documentos.cdcia_usuaria%type,
    oclbRta                        out      clob,
    onmbError                      out      number,
    ovchMessaje                    out      varchar2);    

procedure Verifica$SiNotifica(
     inmbid                         in      number,
     oclbXML                        out     clob);

procedure Grabar$Notificacion(
    ircrRecord                      in      rtytzfw_notificac_eventos,
    oclbXML                         out     clob);
    
procedure UpdateTipoDespre(
    onmbError                      out      number,
    ovchMessaje                    out      varchar2,
    ivchPlaca                      in       tzfw_camiones.cdplaca%type,
    idtFeIngreso                   in       tzfw_camiones.feingreso%type,
    ivchTipo                       in       tzfw_camiones.CDTIPODESPRECINTE%type,
    ivchComentario                 in       tzfw_camiones.DSCOMENTARIODESPRE%type);
procedure xPlaca(
        ivchCia                      in      tzfw_transitos_documentos.cdcia_usuaria%type,
        ivchTransito                 in      tzfw_transitos_documentos.nmtransito%type,
        oclbXML                         out     clob);    
end zfstzfw_transitos_documentos;

/
