import { ScrollView } from 'react-native';
import { StyleSheet } from 'react-native';
import { StatusBar } from 'expo-status-bar';

export default function Html({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta httpEquiv="X-UA-Compatible" content="IE=edge" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <style>{styles}</style>
      </head>
      <body>
        <ScrollView style={{ flex: 1 }}>
          {children}
          <StatusBar style="auto" />
        </ScrollView>
      </body>
    </html>
  );
}

const styles = `
html, body, #root {
  margin: 0;
  padding: 0;
  height: 100%;
  width: 100%;
  overflow: hidden;
}
body {
  display: flex;
  flex: 1;
}
#root {
  display: flex;
  flex: 1;
}
`;