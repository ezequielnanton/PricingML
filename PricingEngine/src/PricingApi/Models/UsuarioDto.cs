namespace PricingApi.Models;

public class UsuarioCreateRequest
{
    public string NombreCompleto { get; set; } = string.Empty;
    public string Usuario { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string Rol { get; set; } = "ADMIN";
    public string? Email { get; set; }
    public List<string> Secciones { get; set; } = new();
}

public class UsuarioLoginRequest
{
    public string Usuario { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class UsuarioLoginResponse
{
    public string Token { get; set; } = string.Empty;
    public int UsuarioID { get; set; }
    public string NombreCompleto { get; set; } = string.Empty;
    public string Rol { get; set; } = string.Empty;
    public List<string> Secciones { get; set; } = new();
    public bool ModoOscuro { get; set; }
}

public class UsuarioActivoRequest
{
    public bool Activo { get; set; }
}

public class UsuarioCambiarPasswordRequest
{
    public string PasswordActual { get; set; } = string.Empty;
    public string PasswordNueva { get; set; } = string.Empty;
}

public class UsuarioSeccionesRequest
{
    public List<string> Secciones { get; set; } = new();
}

public class UsuarioEmailRequest
{
    public string? Email { get; set; }
}

public class UsuarioModoOscuroRequest
{
    public bool ModoOscuro { get; set; }
}

public class UsuarioResumen
{
    public int UsuarioID { get; set; }
    public string NombreCompleto { get; set; } = string.Empty;
    public string Usuario { get; set; } = string.Empty;
    public string Rol { get; set; } = string.Empty;
    public string? Email { get; set; }
    public bool Activo { get; set; }
    public List<string> Secciones { get; set; } = new();
}
