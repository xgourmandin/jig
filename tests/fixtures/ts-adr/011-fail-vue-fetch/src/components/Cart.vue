<script>
export default {
  async mounted() {
    this.items = await fetch("/api/items");
  },
};
</script>
