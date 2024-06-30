import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class CheckDBConnection {

    public static void main(String[] args) {
        try {
            // Stabilisci una connessione
            Connection connection = DButil.getConnection();

            // Crea uno statement
            Statement statement = connection.createStatement();

            // Esegui una semplice query (ad esempio, seleziona la data corrente)
            ResultSet resultSet = statement.executeQuery("SELECT current_date");

            // Verifica se la query è stata eseguita con successo
            if (resultSet.next()) {
                System.out.println("Connesso al database con successo!");
                System.out.println("Data corrente: " + resultSet.getDate(1));
            } else {
                System.out.println("Impossibile eseguire la query.");
            }

            // Chiudi le risorse
            resultSet.close();
            statement.close();
            connection.close();
        } catch (SQLException e) {
            e.printStackTrace();
            System.out.println("Impossibile connettersi al database.");
        }
    }
}
