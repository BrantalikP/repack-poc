import { StatusBar } from 'expo-status-bar';
import { StyleSheet, Text, View } from 'react-native';

// Bump this marker (v1 -> v2 -> ...) to prove a repack actually swapped the JS bundle.
const JS_MARKER = 'v3';

export default function App() {
  return (
    <View style={styles.container}>
      <Text style={styles.marker}>JS build marker: {JS_MARKER}</Text>
      <StatusBar style="auto" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  marker: {
    fontSize: 28,
    fontWeight: 'bold',
  },
});
