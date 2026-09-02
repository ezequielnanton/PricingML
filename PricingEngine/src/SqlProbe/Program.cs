using System;
using Microsoft.Data.SqlClient;

var cs = "Server=localhost\\SQLEXPRESS;Database=master;Integrated Security=True;TrustServerCertificate=True;";
try
{
    using var conn = new SqlConnection(cs);
    conn.Open();
    using var cmd = new SqlCommand("SELECT @@SERVERNAME, DB_NAME()", conn);
    using var reader = cmd.ExecuteReader();
    while (reader.Read())
    {
        Console.WriteLine($"SERVER: {reader[0]} | DB: {reader[1]}");
    }
    Console.WriteLine("CONNECTION_OK");
}
catch (Exception ex)
{
    Console.WriteLine("CONNECTION_ERROR");
    Console.WriteLine(ex.Message);
    Environment.ExitCode = 1;
}
